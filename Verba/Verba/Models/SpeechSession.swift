import Foundation
import SwiftData

@Model
final class SpeechSession {
    var prompt: String
    var category: String
    var transcript: String
    var audioFileName: String?
    var durationSeconds: Double
    var fillerWordCount: Int
    var wordsPerMinute: Double
    var overallScore: Double?
    var feedbackJSON: Data?
    var createdAt: Date

    init(
        prompt: String,
        category: String,
        transcript: String = "",
        audioFileName: String? = nil,
        durationSeconds: Double = 0,
        fillerWordCount: Int = 0,
        wordsPerMinute: Double = 0,
        overallScore: Double? = nil,
        feedbackJSON: Data? = nil,
        createdAt: Date = .now
    ) {
        self.prompt = prompt
        self.category = category
        self.transcript = transcript
        self.audioFileName = audioFileName
        self.durationSeconds = durationSeconds
        self.fillerWordCount = fillerWordCount
        self.wordsPerMinute = wordsPerMinute
        self.overallScore = overallScore
        self.feedbackJSON = feedbackJSON
        self.createdAt = createdAt
    }
}

struct SessionFeedback: Codable {
    var structure: Int
    var clarity: Int
    var relevance: Int
    var conciseness: Int
    var strengths: [String]
    var improvements: [String]
    var summary: String
}

extension SpeechSession {
    var feedback: SessionFeedback? {
        get {
            guard let data = feedbackJSON else { return nil }
            return try? JSONDecoder().decode(SessionFeedback.self, from: data)
        }
        set {
            feedbackJSON = try? JSONEncoder().encode(newValue)
            if let fb = newValue {
                overallScore = Double(fb.structure + fb.clarity + fb.relevance + fb.conciseness) / 4.0
            }
        }
    }
}
