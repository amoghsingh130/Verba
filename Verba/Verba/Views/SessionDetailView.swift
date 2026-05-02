import SwiftUI

struct SessionDetailView: View {
    let session: SpeechSession

    @State private var audio = AudioManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statsCard

                if !session.transcript.isEmpty {
                    transcriptCard
                }

                if let fileName = session.audioFileName,
                   AudioManager.audioFileExists(named: fileName) {
                    playbackCard(fileName: fileName)
                }

                if let feedback = session.feedback {
                    feedbackCard(feedback)
                } else {
                    pendingFeedbackCard
                }
            }
            .padding()
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsCard: some View {
        VStack(spacing: 12) {
            Text(session.prompt)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(session.category.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.categoryColor(session.category))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.categoryColor(session.category).opacity(0.12))
                .clipShape(Capsule())

            Divider()

            HStack(spacing: 16) {
                statItem(value: formatDuration(session.durationSeconds), label: "Duration")
                statItem(value: "\(Int(session.wordsPerMinute))", label: "WPM")
                statItem(value: "\(session.fillerWordCount)", label: "Fillers")
                if let score = session.overallScore {
                    statItem(value: String(format: "%.1f", score), label: "Score")
                }
            }

            Text(session.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(session.transcript)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func playbackCard(fileName: String) -> some View {
        HStack {
            Button {
                let url = AudioManager.audioFileURL(named: fileName)
                if audio.state == .playing {
                    audio.stopPlayback()
                } else {
                    try? audio.play(url: url)
                }
            } label: {
                Label(
                    audio.state == .playing ? "Stop" : "Play Recording",
                    systemImage: audio.state == .playing ? "stop.fill" : "play.fill"
                )
            }
            .buttonStyle(.bordered)

            if audio.state == .playing {
                ProgressView(value: audio.currentTime, total: audio.duration > 0 ? audio.duration : 1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func feedbackCard(_ feedback: SessionFeedback) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Feedback")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

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
                    ForEach(feedback.strengths, id: \.self) { strength in
                        Label(strength, systemImage: "checkmark.circle.fill")
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var pendingFeedbackCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("Feedback Pending")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("AI feedback will appear here once connected.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func scoreItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(Theme.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
