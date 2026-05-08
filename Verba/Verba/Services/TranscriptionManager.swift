import Speech
import Observation

@Observable
final class TranscriptionManager {
    private(set) var transcript: String = ""
    private(set) var fillerWords: [FillerDetection] = []
    private(set) var wordCount: Int = 0
    private(set) var isTranscribing: Bool = false

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    struct FillerDetection: Identifiable {
        let id = UUID()
        let word: String
        let timestamp: TimeInterval
    }

    private static let fillerPatterns: Set<String> = [
        "um", "uh", "uhh", "umm", "hmm", "hm",
        "er", "ah", "eh"
    ]

    private static let discourseFillersInContext: Set<String> = [
        "like", "basically", "literally", "actually",
        "you know", "i mean", "kind of", "sort of"
    ]

    // MARK: - Permissions

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Transcription

    @discardableResult
    func start() -> Bool {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer, recognizer.isAvailable else { return false }
        guard recognizer.supportsOnDeviceRecognition else { return false }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = true

        recognitionRequest = request
        isTranscribing = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.processTranscription(text)
                }
                if result.isFinal {
                    Task { @MainActor in
                        self.isTranscribing = false
                    }
                }
            }
            if error != nil {
                Task { @MainActor in
                    self.isTranscribing = false
                }
            }
        }
        return true
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func stop() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        // Don't cancel the task — let it deliver the final transcript.
        // It will set isTranscribing = false when isFinal arrives or on error.
    }

    func reset() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil
        isTranscribing = false
        transcript = ""
        fillerWords = []
        wordCount = 0
    }

    // MARK: - Analysis

    private func processTranscription(_ text: String) {
        transcript = text
        let words = text.lowercased().split(separator: " ").map(String.init)
        wordCount = words.count
        detectFillers(in: text.lowercased())
    }

    private func detectFillers(in text: String) {
        var detections: [FillerDetection] = []
        let words = text.split(separator: " ").map { String($0).trimmingCharacters(in: .punctuationCharacters) }

        for word in words {
            if Self.fillerPatterns.contains(word) {
                detections.append(FillerDetection(word: word, timestamp: 0))
            }
        }

        // Check multi-word fillers
        let joined = words.joined(separator: " ")
        for phrase in Self.discourseFillersInContext {
            var searchRange = joined.startIndex..<joined.endIndex
            while let range = joined.range(of: phrase, range: searchRange) {
                detections.append(FillerDetection(word: phrase, timestamp: 0))
                searchRange = range.upperBound..<joined.endIndex
            }
        }

        fillerWords = detections
    }

    var fillerCount: Int { fillerWords.count }

    func wordsPerMinute(duration: TimeInterval) -> Double {
        guard duration > 5 else { return 0 }
        return Double(wordCount) / (duration / 60.0)
    }
}
