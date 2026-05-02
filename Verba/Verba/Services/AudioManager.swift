import AVFoundation
import Observation

@Observable
final class AudioManager {
    enum State: Equatable {
        case idle
        case recording
        case playing
    }

    private(set) var state: State = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var audioLevel: Float = 0

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var recordingStartTime: Date?

    private(set) var currentFileURL: URL?

    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    // MARK: - Recording

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let fileURL = Self.newRecordingURL()
        currentFileURL = fileURL

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        )!

        let file = try AVAudioFile(forWriting: fileURL, settings: recordingFormat.settings)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            try? file.write(from: buffer)
            self?.updateAudioLevel(buffer: buffer)
            self?.onBuffer?(buffer)
        }

        try engine.start()

        audioEngine = engine
        audioFile = file
        recordingStartTime = .now
        state = .recording

        startTimer()
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil

        stopTimer()

        let recordedDuration = currentTime
        let url = currentFileURL

        state = .idle
        currentTime = 0
        audioLevel = 0
        recordingStartTime = nil

        guard let url else { return nil }
        return (url, recordedDuration)
    }

    // MARK: - Playback

    func play(url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        duration = player.duration
        player.play()

        audioPlayer = player
        state = .playing

        startTimer()
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopTimer()

        currentTime = 0
        duration = 0
        state = .idle
    }

    // MARK: - File Management

    static func newRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        let fileName = "verba_\(Int(Date().timeIntervalSince1970)).wav"
        return recordingsDir.appendingPathComponent(fileName)
    }

    static func audioFileExists(named fileName: String) -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("Recordings/\(fileName)")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func audioFileURL(named fileName: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Recordings/\(fileName)")
    }

    // MARK: - Permissions

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Private

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrtf(sum / Float(frames))
        let level = max(0, min(1, rms * 5))
        Task { @MainActor in
            self.audioLevel = level
        }
    }

    private func startTimer() {
        let link = CADisplayLink(target: self, selector: #selector(timerTick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func timerTick() {
        switch state {
        case .recording:
            if let start = recordingStartTime {
                currentTime = Date().timeIntervalSince(start)
            }
        case .playing:
            if let player = audioPlayer {
                currentTime = player.currentTime
                if !player.isPlaying {
                    stopPlayback()
                }
            }
        case .idle:
            break
        }
    }
}
