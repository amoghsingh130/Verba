import Foundation

struct FeedbackService {
    static var workerURL = URL(string: "https://verba-feedback.verba-feedback.workers.dev")!

    static var deviceID: String {
        let key = "com.verba.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }

    struct FeedbackRequest: Encodable {
        let prompt: String
        let transcript: String
        let durationSeconds: Double
        let fillerWordCount: Int
        let wordsPerMinute: Double
    }

    static func requestFeedback(for session: SpeechSession) async throws -> SessionFeedback {
        let requestBody = FeedbackRequest(
            prompt: session.prompt,
            transcript: session.transcript,
            durationSeconds: session.durationSeconds,
            fillerWordCount: session.fillerWordCount,
            wordsPerMinute: session.wordsPerMinute
        )

        var request = URLRequest(url: workerURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceID, forHTTPHeaderField: "x-device-id")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FeedbackError.network
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackError.server(statusCode: 0)
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(SessionFeedback.self, from: data)
        case 429:
            throw FeedbackError.rateLimited
        case 503:
            throw FeedbackError.unavailable
        default:
            throw FeedbackError.server(statusCode: httpResponse.statusCode)
        }
    }

    enum FeedbackError: LocalizedError {
        case network
        case rateLimited
        case unavailable
        case server(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .network:
                return "No internet connection. Check your network and try again."
            case .rateLimited:
                return "You've reached today's session limit. Try again tomorrow."
            case .unavailable:
                return "Feedback service is temporarily unavailable."
            case .server(let code):
                return "Something went wrong (error \(code)). Please try again."
            }
        }
    }
}
