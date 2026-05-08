import SwiftUI
import SwiftData

struct PracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let prompt: SpeechPrompt

    enum Phase {
        case prep
        case countdown(Int)
        case recording
        case review
    }

    enum PracticeAlert: Identifiable {
        case micPermission
        case speechPermission
        case onDeviceUnavailable
        case interruption
        case backgrounded

        var id: String { String(describing: self) }

        var title: String {
            switch self {
            case .micPermission: return "Microphone Access"
            case .speechPermission: return "Speech Recognition Access"
            case .onDeviceUnavailable: return "On-Device Transcription Unavailable"
            case .interruption: return "Recording Interrupted"
            case .backgrounded: return "Session Stopped"
            }
        }

        var message: String {
            switch self {
            case .micPermission:
                return "Verba needs microphone access to record your speech. Enable it in Settings."
            case .speechPermission:
                return "Verba needs speech recognition access to transcribe your sessions on-device. Enable it in Settings."
            case .onDeviceUnavailable:
                return "Verba transcribes your speech entirely on your device so audio never leaves your phone. This device doesn't support on-device speech recognition, so practice sessions can't be recorded."
            case .interruption:
                return "Your session was interrupted by another audio source — likely a phone call or Siri. Tap record to start a new session."
            case .backgrounded:
                return "Verba pauses recording when the app goes to the background. Tap record to start a new session."
            }
        }

        var routesToSettings: Bool {
            switch self {
            case .micPermission, .speechPermission: return true
            default: return false
            }
        }
    }

    @State private var phase: Phase = .prep
    @State private var audio = AudioManager()
    @State private var transcription = TranscriptionManager()
    @State private var hasMicPermission = false
    @State private var hasSpeechPermission = false
    @State private var activeAlert: PracticeAlert?
    @State private var recordingResult: (url: URL, duration: TimeInterval)?
    @State private var savedSession: SpeechSession?
    @State private var isFetchingFeedback = false
    @State private var feedbackError: FeedbackService.FeedbackError?

    var body: some View {
        Group {
            switch phase {
            case .recording:
                recordingFullscreen
            case .countdown(let count):
                countdownFullscreen(count)
            default:
                ScrollView {
                    VStack(spacing: 24) {
                        promptCard
                        if case .prep = phase { prepPhase }
                        if case .review = phase { reviewPhase }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(isRecordingOrCountdown ? "" : "Practice")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(isRecordingOrCountdown)
        .navigationBarBackButtonHidden(isRecordingOrCountdown)
        .toolbar(isRecordingOrCountdown ? .hidden : .visible, for: .tabBar)
        .alert(item: $activeAlert) { alert in
            if alert.routesToSettings {
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Open Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel()
                )
            } else {
                return Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .task {
            hasMicPermission = await AudioManager.requestPermission()
            hasSpeechPermission = await TranscriptionManager.requestPermission()
        }
    }

    private var isRecordingOrCountdown: Bool {
        switch phase {
        case .recording, .countdown: return true
        default: return false
        }
    }

    // MARK: - Prompt Card

    private var promptCard: some View {
        VStack(spacing: 10) {
            Text(prompt.category.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.categoryColor(prompt.category))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.categoryColor(prompt.category).opacity(0.12))
                .clipShape(Capsule())
            Text(prompt.text)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Prep Phase

    private var prepPhase: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image(systemName: "mic.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Take a moment to gather your thoughts, then tap when you're ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                startCountdown()
            } label: {
                Text("I'm Ready")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Spacer().frame(height: 40)
        }
    }

    // MARK: - Countdown Fullscreen

    private func countdownFullscreen(_ count: Int) -> some View {
        ZStack {
            Theme.warmDark.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.primary.opacity(0.18), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Text("\(count)")
                    .font(.system(size: 144, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: count)
                    .shadow(color: Theme.primary.opacity(0.4), radius: 24)

                Text("Get ready")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Recording Fullscreen

    private var recordingFullscreen: some View {
        ZStack {
            Theme.warmDark.ignoresSafeArea()

            VStack(spacing: 0) {
                Text(formatTime(audio.currentTime))
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.top, 40)

                HStack(spacing: 10) {
                    statPill(value: "\(transcription.wordCount)", label: "words")
                    statPill(value: "\(transcription.fillerCount)", label: "fillers")
                }
                .padding(.top, 14)

                Spacer()

                AudioWaveformView(level: audio.audioLevel)

                Spacer()

                liveTranscriptView
                    .frame(maxHeight: 160)
                    .padding(.horizontal, 24)

                Button(action: stopRecording) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 76, height: 76)
                            .shadow(color: .red.opacity(0.45), radius: 18)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 26, height: 26)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
        }
    }

    private func statPill(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private var liveTranscriptView: some View {
        ScrollView {
            Text(transcription.transcript.isEmpty ? "Start speaking..." : transcription.transcript)
                .font(.body)
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .italic(transcription.transcript.isEmpty)
        }
        .mask(
            LinearGradient(
                colors: [.clear, .black, .black, .black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Review Phase

    private var reviewPhase: some View {
        VStack(spacing: 20) {
            if let result = recordingResult {
                postRecordingStats(duration: result.duration)
            }

            transcriptCard

            if let result = recordingResult {
                playbackControls(result: result)
            }

            if savedSession != nil {
                feedbackPendingCard
            } else {
                tooShortCard
            }
        }
    }

    private var tooShortCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("Too short for feedback")
                .font(.headline)
            Text("Speak for at least a few seconds so we can analyze your response.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Button {
                    retryRecording()
                } label: {
                    Label("Re-record", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderedProminent)
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var feedbackPendingCard: some View {
        VStack(spacing: 12) {
            if isFetchingFeedback {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Getting AI feedback...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let feedback = savedSession?.feedback {
                feedbackContent(feedback)
            } else if let error = feedbackError {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Feedback Failed")
                    .font(.headline)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if case .rateLimited = error {
                    EmptyView()
                } else {
                    Button("Retry") {
                        retryFeedback()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func feedbackContent(_ feedback: SessionFeedback) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text("AI Feedback")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                scoreItem(value: feedback.structure, label: "Structure")
                scoreItem(value: feedback.clarity, label: "Clarity")
                scoreItem(value: feedback.relevance, label: "Relevance")
                scoreItem(value: feedback.conciseness, label: "Concise")
            }

            if !feedback.strengths.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Strengths")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    ForEach(feedback.strengths, id: \.self) { s in
                        Label(s, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }
            }

            if !feedback.improvements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Areas to Improve")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    ForEach(feedback.improvements, id: \.self) { item in
                        Label(item, systemImage: "arrow.up.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            }

            if !feedback.summary.isEmpty {
                Text(feedback.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scoreItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Shared Subviews

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(audio.state == .recording ? "Live Transcript" : "Transcript")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                if transcription.isTranscribing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if transcription.transcript.isEmpty {
                Text("Start speaking...")
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(transcription.transcript)
                    .font(.body)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func postRecordingStats(duration: TimeInterval) -> some View {
        HStack(spacing: 16) {
            statItem(value: "\(transcription.wordCount)", label: "Words")
            statItem(value: "\(Int(transcription.wordsPerMinute(duration: duration)))", label: "WPM")
            statItem(value: "\(transcription.fillerCount)", label: "Fillers")
            statItem(value: formatTime(duration), label: "Duration")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func playbackControls(result: (url: URL, duration: TimeInterval)) -> some View {
        VStack(spacing: 12) {
            if audio.state == .playing {
                ProgressView(value: audio.currentTime, total: audio.duration > 0 ? audio.duration : 1)
            }

            HStack(spacing: 24) {
                Button {
                    if audio.state == .playing {
                        audio.stopPlayback()
                    } else {
                        try? audio.play(url: result.url)
                    }
                } label: {
                    Label(
                        audio.state == .playing ? "Stop" : "Play",
                        systemImage: audio.state == .playing ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Actions

    private func startCountdown() {
        guard hasMicPermission else {
            activeAlert = .micPermission
            return
        }
        guard hasSpeechPermission else {
            activeAlert = .speechPermission
            return
        }
        phase = .countdown(3)
        Task {
            for i in stride(from: 2, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                phase = .countdown(i)
            }
            try? await Task.sleep(for: .seconds(0.5))
            beginRecording()
        }
    }

    private func beginRecording() {
        transcription.reset()
        guard transcription.start() else {
            phase = .prep
            activeAlert = .onDeviceUnavailable
            return
        }
        audio.onBuffer = { buffer in
            transcription.appendBuffer(buffer)
        }
        audio.onInterruption = {
            transcription.reset()
            recordingResult = nil
            phase = .prep
            activeAlert = .interruption
        }
        try? audio.startRecording()
        phase = .recording
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase != .active else { return }
        switch phase {
        case .recording:
            _ = audio.stopRecording()
            audio.stopPlayback()
            transcription.reset()
            recordingResult = nil
            phase = .prep
            activeAlert = .backgrounded
        case .countdown:
            transcription.reset()
            phase = .prep
            activeAlert = .backgrounded
        case .prep, .review:
            break
        }
    }

    private func stopRecording() {
        transcription.stop()
        recordingResult = audio.stopRecording()
        phase = .review

        // Auto-save and fetch feedback if the recording is substantial
        if isTranscriptSubstantial {
            saveSession()
        }
    }

    private var isTranscriptSubstantial: Bool {
        let duration = recordingResult?.duration ?? 0
        return duration >= 3 && transcription.wordCount >= 5
    }

    private func retryRecording() {
        audio.stopPlayback()
        transcription.reset()
        recordingResult = nil
        savedSession = nil
        phase = .prep
    }

    private func saveSession() {
        guard let result = recordingResult else { return }
        let fileName = result.url.lastPathComponent
        let wpm = transcription.wordsPerMinute(duration: result.duration)
        let session = SpeechSession(
            prompt: prompt.text,
            category: prompt.category,
            transcript: transcription.transcript,
            audioFileName: fileName,
            durationSeconds: result.duration,
            fillerWordCount: transcription.fillerCount,
            wordsPerMinute: wpm
        )
        modelContext.insert(session)
        savedSession = session
        fetchFeedback(for: session)
    }

    private func fetchFeedback(for session: SpeechSession) {
        isFetchingFeedback = true
        feedbackError = nil
        Task {
            do {
                let feedback = try await FeedbackService.requestFeedback(for: session)
                session.feedback = feedback
                isFetchingFeedback = false
            } catch let error as FeedbackService.FeedbackError {
                feedbackError = error
                isFetchingFeedback = false
            } catch {
                feedbackError = .server(statusCode: 0)
                isFetchingFeedback = false
            }
        }
    }

    private func retryFeedback() {
        guard let session = savedSession else { return }
        fetchFeedback(for: session)
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
