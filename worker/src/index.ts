interface Env {
	ANTHROPIC_API_KEY: string;
	RATE_LIMIT: KVNamespace;
}

interface FeedbackRequest {
	prompt: string;
	transcript: string;
	durationSeconds: number;
	fillerWordCount: number;
	wordsPerMinute: number;
}

const feedbackTool = {
	name: "provide_feedback",
	description: "Provide structured feedback on an impromptu speech.",
	input_schema: {
		type: "object" as const,
		properties: {
			structure: { type: "number", description: "Score 1-10 for logical organization and flow" },
			clarity: { type: "number", description: "Score 1-10 for clear expression of ideas" },
			relevance: { type: "number", description: "Score 1-10 for staying on topic and addressing the prompt" },
			conciseness: { type: "number", description: "Score 1-10 for being succinct without unnecessary filler" },
			strengths: { type: "array", items: { type: "string" }, description: "2-3 specific things done well" },
			improvements: { type: "array", items: { type: "string" }, description: "2-3 specific actionable suggestions" },
			summary: { type: "string", description: "1-2 sentence overall assessment" },
		},
		required: ["structure", "clarity", "relevance", "conciseness", "strengths", "improvements", "summary"],
	},
};

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		if (request.method === "OPTIONS") {
			return new Response(null, {
				headers: {
					"Access-Control-Allow-Origin": "*",
					"Access-Control-Allow-Methods": "POST",
					"Access-Control-Allow-Headers": "Content-Type",
				},
			});
		}

		if (request.method !== "POST") {
			return Response.json({ error: "Method not allowed" }, { status: 405 });
		}

		try {
			const deviceId = request.headers.get("x-device-id") || "anonymous";
			const today = new Date().toISOString().split("T")[0];

			// Per-device daily limit (personal testing phase)
			const PER_DEVICE_DAILY_LIMIT = 20;
			const rateLimitKey = `${deviceId}:${today}`;
			const currentCount = await env.RATE_LIMIT.get(rateLimitKey);
			const count = currentCount ? parseInt(currentCount) : 0;

			if (count >= PER_DEVICE_DAILY_LIMIT) {
				return Response.json(
					{ error: "Daily rate limit exceeded." },
					{ status: 429 }
				);
			}

			// Global daily safety cap to protect the API budget
			const GLOBAL_DAILY_LIMIT = 300;
			const globalKey = `global:${today}`;
			const globalCountRaw = await env.RATE_LIMIT.get(globalKey);
			const globalCount = globalCountRaw ? parseInt(globalCountRaw) : 0;

			if (globalCount >= GLOBAL_DAILY_LIMIT) {
				return Response.json(
					{ error: "Service temporarily unavailable." },
					{ status: 503 }
				);
			}

			const body = (await request.json()) as FeedbackRequest;
			let { prompt, transcript, durationSeconds, fillerWordCount, wordsPerMinute } = body;

			if (!transcript || !prompt) {
				return Response.json({ error: "Missing prompt or transcript" }, { status: 400 });
			}

			// Cap transcript at ~1000 tokens of input to bound cost
			const MAX_TRANSCRIPT_CHARS = 4000;
			if (transcript.length > MAX_TRANSCRIPT_CHARS) {
				transcript = transcript.slice(0, MAX_TRANSCRIPT_CHARS);
			}

			const systemPrompt = `You are an impromptu speaking coach. Give specific, encouraging feedback via the provide_feedback tool. Context: ${Math.round(wordsPerMinute)} WPM, ${fillerWordCount} fillers in ${Math.round(durationSeconds)}s.`;

			const response = await fetch("https://api.anthropic.com/v1/messages", {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					"x-api-key": env.ANTHROPIC_API_KEY,
					"anthropic-version": "2023-06-01",
				},
				body: JSON.stringify({
					model: "claude-haiku-4-5",
					max_tokens: 500,
					system: systemPrompt,
					tools: [feedbackTool],
					tool_choice: { type: "tool", name: "provide_feedback" },
					messages: [
						{
							role: "user",
							content: `Prompt: "${prompt}"\n\nTranscript: "${transcript}"`,
						},
					],
				}),
			});

			if (!response.ok) {
				const errText = await response.text();
				return Response.json({ error: "Claude API error", details: errText }, { status: 502 });
			}

			const result = (await response.json()) as {
				content: Array<{ type: string; input?: Record<string, unknown> }>;
			};
			const toolUse = result.content.find((c) => c.type === "tool_use");

			if (!toolUse?.input) {
				return Response.json({ error: "No feedback returned" }, { status: 502 });
			}

			// Only count successful requests against quotas
			await env.RATE_LIMIT.put(rateLimitKey, String(count + 1), { expirationTtl: 86400 });
			await env.RATE_LIMIT.put(globalKey, String(globalCount + 1), { expirationTtl: 86400 });

			return Response.json(toolUse.input, {
				headers: {
					"Content-Type": "application/json",
					"Access-Control-Allow-Origin": "*",
				},
			});
		} catch (e) {
			return Response.json({ error: "Internal error", details: String(e) }, { status: 500 });
		}
	},
};
