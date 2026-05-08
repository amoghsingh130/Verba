import Speech
import Observation
import AVFoundation
import QuartzCore

@Observable
final class TranscriptionManager {
    private(set) var transcript: String = ""
    private(set) var fillerWords: [FillerDetection] = []
    private(set) var wordCount: Int = 0
    private(set) var isTranscribing: Bool = false

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var completedSegments: [String] = []
    private var currentPartial: String = ""

    // Silence-based task rotation: forces isFinal so we can flush + restart.
    private var lastNonSilenceTime: CFTimeInterval = 0
    private var rotationPending = false
    private static let silenceRMSThreshold: Float = 0.005
    private static let silenceRotateDuration: CFTimeInterval = 1.2

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

        completedSegments = []
        currentPartial = ""
        lastNonSilenceTime = 0
        rotationPending = false
        isTranscribing = true
        return startNewRecognitionTask()
    }

    @discardableResult
    private func startNewRecognitionTask() -> Bool {
        guard let recognizer else { return false }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = true

        recognitionRequest = request
        rotationPending = false
        lastNonSilenceTime = 0

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                Task { @MainActor in
                    self.handleResultText(text, isFinal: isFinal)
                }
            }

            if error != nil {
                Task { @MainActor in
                    self.finalizeCurrentSegment()
                    if self.isTranscribing {
                        _ = self.startNewRecognitionTask()
                    }
                }
            }
        }
        return true
    }

    @MainActor
    private func handleResultText(_ text: String, isFinal: Bool) {
        // Safety net: if the new cumulative text doesn't extend the current partial
        // and is materially shorter, the recognizer silently rolled the segment.
        // Flush the previous partial as a completed segment before overwriting.
        if !currentPartial.isEmpty,
           !text.hasPrefix(currentPartial),
           text.count < currentPartial.count / 2 {
            completedSegments.append(currentPartial)
            currentPartial = ""
        }

        currentPartial = text
        refreshTranscript()

        if isFinal {
            finalizeCurrentSegment()
            if isTranscribing {
                _ = startNewRecognitionTask()
            }
        }
    }

    @MainActor
    private func finalizeCurrentSegment() {
        let trimmed = currentPartial.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            completedSegments.append(trimmed)
        }
        currentPartial = ""
        refreshTranscript()
    }

    @MainActor
    private func refreshTranscript() {
        let combined = (completedSegments + [currentPartial])
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        processTranscription(combined)
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
        checkForSilence(buffer: buffer)
    }

    private func checkForSilence(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrtf(sum / Float(frames))
        let now = CACurrentMediaTime()

        if rms > Self.silenceRMSThreshold {
            lastNonSilenceTime = now
        } else if lastNonSilenceTime > 0,
                  (now - lastNonSilenceTime) > Self.silenceRotateDuration,
                  !rotationPending {
            rotationPending = true
            Task { @MainActor in
                self.rotateOnSilence()
            }
        }
    }

    @MainActor
    private func rotateOnSilence() {
        guard isTranscribing else {
            rotationPending = false
            return
        }
        // Forces the current task to finalize. The result callback will then
        // append the partial to completedSegments and start a new task.
        recognitionRequest?.endAudio()
    }

    func stop() {
        isTranscribing = false
        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }

    func reset() {
        isTranscribing = false
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil
        completedSegments = []
        currentPartial = ""
        lastNonSilenceTime = 0
        rotationPending = false
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
