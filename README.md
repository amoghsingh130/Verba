# Verba

**Get better at thinking on your feet.**

Verba is an iOS app that turns impromptu speaking from a vague soft skill into a measurable practice. Tap a category, get a prompt, talk for sixty seconds, and walk away with structured feedback from Claude on how you actually did — and a long-term picture of how you're improving.

Built for interview prep, public speaking practice, and anyone who's ever been caught off-guard by "so, tell me about yourself."

---

## What it does

**Practice.** Pick a category — Leadership, Behavioral, Big Picture, Business, Personal Growth, Education — and you'll get a fresh prompt at your difficulty level. Hit record, talk, hit stop. The app transcribes you live (on-device, no audio ever leaves your phone) and shows a real-time waveform, timer, and word counter while you go.

**Get scored.** When you finish, your transcript gets sent to Claude Haiku 4.5 through a custom Cloudflare Worker. Within seconds, you get scores across four dimensions — structure, clarity, relevance, conciseness — plus two or three specific strengths, two or three specific things to work on, and a one-line summary of how the whole thing landed.

**Track progress.** Every session lands in your history with the prompt, transcript, scores, and feedback. The Progress tab visualizes your trajectory over 7 days, 30 days, or all-time — score trends, filler-word counts, words-per-minute, current streak, best session.

**Learn the craft.** Sixteen long-form articles on the actual technique of public and impromptu speaking — frameworks like PREP and STAR, breath control, dealing with stage fright, handling hostile questions, reading a room. Each article ends with a drill you can run right there in the Practice tab.

---

## How it's built

A SwiftUI iOS client and a Cloudflare Worker backend. That's the whole thing.

### The iOS app

- **SwiftUI + SwiftData** for the UI and persistence — no UIKit, no Core Data
- **AVAudioEngine + SFSpeechRecognizer** for on-device transcription — your voice never touches a server
- **Swift Charts** for the analytics dashboard
- **Custom design system** in `Models/Theme.swift` — warm-amber primary palette with per-category accent colors, full dark-first recording experience
- **Custom audio waveform view** — concentric pulsing rings around an amber gradient core, all SwiftUI Canvas

### The backend

A single TypeScript file deployed on Cloudflare Workers. It does three things:
1. Forwards your transcript to the Anthropic API
2. Constrains Claude's response to a strict JSON schema using tool-use, so the app never has to guess at malformed output
3. Enforces per-device and global daily rate limits via Cloudflare KV — successful calls only, so failures don't burn quota

The whole pipeline costs about **$0.002 per session**. A hard global cap of 300 calls/day means the worst-case daily spend is sixty cents.

### Why Haiku, not Sonnet

Originally prototyped with Claude Sonnet, then swapped to Claude Haiku 4.5. The output quality on this specific task — short transcripts, structured scoring, a few sentences of feedback — is indistinguishable. The cost dropped roughly 3x. There was no reason not to.

---

## Privacy

This is an audio app that doesn't send your audio anywhere. Speech-to-text happens on your phone. Only the transcribed text is sent to the backend, and only when you finish a session. Nothing is logged or persisted server-side — the Worker is stateless except for daily rate-limit counters.

Your sessions, scores, and history are stored locally in SwiftData and never leave your device.

---

## Repo layout

```
impromptu-speaking-coach/
├── Verba/                    # Xcode project (iOS app)
│   └── Verba/
│       ├── Models/           # SwiftData models, theme, content loaders
│       ├── Views/            # All SwiftUI screens
│       ├── Services/         # Audio, transcription, feedback API client
│       └── Resources/        # 92 prompts + 16 articles (JSON)
└── worker/                   # Cloudflare Worker backend
    └── src/index.ts          # Single-file Anthropic proxy + rate limiter
```

---

## Running it locally

**iOS app:** open `Verba/Verba.xcodeproj` in Xcode 16, target a real device (speech recognition is unreliable in the simulator), build and run.

**Worker:** the deployed version is live at `https://verba-feedback.verba-feedback.workers.dev` and the app already points at it. To run your own:

```bash
cd worker
npm install
npx wrangler secret put ANTHROPIC_API_KEY    # paste your key
npx wrangler deploy
```

Then update `workerURL` in `Verba/Verba/Services/FeedbackService.swift`.

---

## Status

Feature-complete for personal daily use. Currently working through pre-submission steps for the App Store: App Attest for Worker authentication, privacy manifest, polish pass, TestFlight, then submission.

Free, no monetization planned. Built because I wanted it to exist.
