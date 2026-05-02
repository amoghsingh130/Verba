import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            PracticeTab()
                .tabItem { Label("Practice", systemImage: "mic.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            DashboardView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            LearnView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
        }
        .tint(Theme.primary)
    }
}

private struct PracticeTab: View {
    @State private var currentPrompt: SpeechPrompt?
    @State private var selectedCategory: String?
    @State private var navigateToPractice = false

    private var categories: [String] { PromptBank.shared.categories }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                categoryPicker
                promptDisplay
                actionButtons
                Spacer()
            }
            .padding()
            .navigationTitle("Verba")
            .navigationDestination(isPresented: $navigateToPractice) {
                if let prompt = currentPrompt {
                    PracticeView(prompt: prompt)
                }
            }
            .onAppear {
                if currentPrompt == nil {
                    currentPrompt = PromptBank.shared.random(category: selectedCategory)
                }
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                    currentPrompt = PromptBank.shared.random()
                }
                ForEach(categories, id: \.self) { category in
                    categoryChip(title: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                        currentPrompt = PromptBank.shared.random(category: category)
                    }
                }
            }
        }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

    private var promptDisplay: some View {
        VStack(spacing: 12) {
            if let prompt = currentPrompt {
                Text(prompt.category.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.categoryColor(prompt.category))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.categoryColor(prompt.category).opacity(0.12))
                    .clipShape(Capsule())
                Text(prompt.text)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(minHeight: 80)
                Text(prompt.difficulty)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                currentPrompt = PromptBank.shared.random(category: selectedCategory)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
            }
            .buttonStyle(.bordered)

            Button {
                navigateToPractice = true
            } label: {
                Label("Start", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(currentPrompt == nil)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SpeechSession.self, inMemory: true)
}
