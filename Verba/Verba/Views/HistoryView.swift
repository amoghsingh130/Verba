import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpeechSession.createdAt, order: .reverse) private var sessions: [SpeechSession]

    @State private var searchText = ""
    @State private var selectedCategory: String?

    private var categories: [String] { PromptBank.shared.categories }

    private var filteredSessions: [SpeechSession] {
        sessions.filter { session in
            let matchesSearch = searchText.isEmpty
                || session.prompt.localizedCaseInsensitiveContains(searchText)
                || session.transcript.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || session.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    private var groupedSessions: [(String, [SpeechSession])] {
        let calendar = Calendar.current
        let now = Date()
        var today: [SpeechSession] = []
        var thisWeek: [SpeechSession] = []
        var earlier: [SpeechSession] = []

        for session in filteredSessions {
            if calendar.isDateInToday(session.createdAt) {
                today.append(session)
            } else if calendar.isDate(session.createdAt, equalTo: now, toGranularity: .weekOfYear) {
                thisWeek.append(session)
            } else {
                earlier.append(session)
            }
        }

        return [("Today", today), ("This Week", thisWeek), ("Earlier", earlier)]
            .filter { !$0.1.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: SpeechSession.self) { session in
                SessionDetailView(session: session)
            }
        }
    }

    private var listContent: some View {
        List {
            if !categories.isEmpty {
                Section {
                    categoryFilter
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            }

            ForEach(groupedSessions, id: \.0) { bucket, items in
                Section(bucket) {
                    ForEach(items) { session in
                        NavigationLink(value: session) {
                            sessionRow(session)
                        }
                    }
                    .onDelete { offsets in
                        delete(from: items, at: offsets)
                    }
                }
            }

            if filteredSessions.isEmpty {
                Section {
                    Text("No sessions match your filters.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search prompts or transcripts")
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(categories, id: \.self) { category in
                    chip(title: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    private func sessionRow(_ session: SpeechSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.categoryColor(session.category))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(session.prompt)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Text(session.category.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.categoryColor(session.category))
                    Text(session.createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 12) {
                    Label(formatDuration(session.durationSeconds), systemImage: "clock")
                    if session.wordsPerMinute > 0 {
                        Label("\(Int(session.wordsPerMinute)) wpm", systemImage: "text.word.spacing")
                    }
                    if session.fillerWordCount > 0 {
                        Label("\(session.fillerWordCount)", systemImage: "exclamationmark.bubble")
                    }
                    if let score = session.overallScore {
                        Label(String(format: "%.1f", score), systemImage: "star.fill")
                            .foregroundStyle(Theme.primary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No sessions yet")
                .font(.headline)
            Text("Completed practice sessions will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func delete(from items: [SpeechSession], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: SpeechSession.self, inMemory: true)
}
