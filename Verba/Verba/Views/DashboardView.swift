import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \SpeechSession.createdAt, order: .forward) private var sessions: [SpeechSession]

    @State private var range: TimeRange = .month

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "7D"
        case month = "30D"
        case all = "All"
        var id: String { rawValue }

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .all: return nil
            }
        }
    }

    private var filteredSessions: [SpeechSession] {
        guard let days = range.days else { return sessions }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return sessions.filter { $0.createdAt >= cutoff }
    }

    private var scoredSessions: [SpeechSession] {
        filteredSessions.filter { $0.overallScore != nil }
    }

    private var totalSessions: Int { sessions.count }

    private var averageScore: Double? {
        let scores = scoredSessions.compactMap { $0.overallScore }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private var bestScore: Double? {
        scoredSessions.compactMap { $0.overallScore }.max()
    }

    private var currentStreak: Int {
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current
        let sessionDays = Set(sessions.map { calendar.startOfDay(for: $0.createdAt) })
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while sessionDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Progress")
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                rangePicker
                summaryGrid

                chartCard(title: "Overall Score", subtitle: "Higher is better (1–10)") {
                    scoreChart
                }

                chartCard(title: "Filler Words", subtitle: "Per session — lower is better") {
                    fillerChart
                }

                chartCard(title: "Pace (WPM)", subtitle: "Words per minute") {
                    wpmChart
                }
            }
            .padding()
        }
    }

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Range", selection: $range) {
                ForEach(TimeRange.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text(rangeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rangeLabel: String {
        let count = filteredSessions.count
        let countText = "\(count) session\(count == 1 ? "" : "s")"
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        switch range {
        case .week:
            let start = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
            return "Last 7 days · \(formatter.string(from: start))–\(formatter.string(from: Date())) · \(countText)"
        case .month:
            let start = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
            return "Last 30 days · \(formatter.string(from: start))–\(formatter.string(from: Date())) · \(countText)"
        case .all:
            return "All time · \(countText)"
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard(label: "Sessions", value: "\(totalSessions)", systemImage: "mic.fill")
            summaryCard(label: "Streak", value: "\(currentStreak)d", systemImage: "flame.fill")
            summaryCard(
                label: "Avg Score",
                value: averageScore.map { String(format: "%.1f", $0) } ?? "—",
                systemImage: "star.fill"
            )
            summaryCard(
                label: "Best Score",
                value: bestScore.map { String(format: "%.1f", $0) } ?? "—",
                systemImage: "trophy.fill"
            )
        }
    }

    private func summaryCard(label: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title, design: .rounded))
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func chartCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            content()
                .frame(height: 180)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var scoreChart: some View {
        Group {
            if scoredSessions.isEmpty {
                chartPlaceholder("No scored sessions yet")
            } else {
                Chart(scoredSessions) { session in
                    LineMark(
                        x: .value("Date", session.createdAt),
                        y: .value("Score", session.overallScore ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.orange)
                    PointMark(
                        x: .value("Date", session.createdAt),
                        y: .value("Score", session.overallScore ?? 0)
                    )
                    .foregroundStyle(.orange)
                }
                .chartYScale(domain: 0...10)
            }
        }
    }

    private var fillerChart: some View {
        Group {
            if filteredSessions.isEmpty {
                chartPlaceholder("No sessions in range")
            } else {
                Chart(filteredSessions) { session in
                    BarMark(
                        x: .value("Date", session.createdAt, unit: .day),
                        y: .value("Fillers", session.fillerWordCount)
                    )
                    .foregroundStyle(.red.gradient)
                }
            }
        }
    }

    private var wpmChart: some View {
        Group {
            let paced = filteredSessions.filter { $0.wordsPerMinute > 0 }
            if paced.isEmpty {
                chartPlaceholder("No pacing data in range")
            } else {
                Chart(paced) { session in
                    LineMark(
                        x: .value("Date", session.createdAt),
                        y: .value("WPM", session.wordsPerMinute)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)
                    PointMark(
                        x: .value("Date", session.createdAt),
                        y: .value("WPM", session.wordsPerMinute)
                    )
                    .foregroundStyle(.blue)
                }
            }
        }
    }

    private func chartPlaceholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.primary.opacity(0.7))
            Text("Your progress will show up here")
                .font(.headline)
            Text("Practice a few sessions and you'll see score trends, streaks, filler-word counts, and words-per-minute over time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: SpeechSession.self, inMemory: true)
}
