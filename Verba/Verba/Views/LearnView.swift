import SwiftUI

struct LearnView: View {
    @State private var selectedCategory: String?
    @State private var searchText = ""

    private let library = TipLibrary.shared

    private var filteredTips: [Tip] {
        library.tips.filter { tip in
            let matchesCategory = selectedCategory == nil || tip.category == selectedCategory
            let matchesSearch = searchText.isEmpty
                || tip.title.localizedCaseInsensitiveContains(searchText)
                || tip.summary.localizedCaseInsensitiveContains(searchText)
                || tip.body.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    private var groupedTips: [(String, [Tip])] {
        if let selected = selectedCategory {
            let items = filteredTips.filter { $0.category == selected }
            return items.isEmpty ? [] : [(selected, items)]
        }
        return library.categories.compactMap { cat in
            let items = filteredTips.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    categoryFilter
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                ForEach(groupedTips, id: \.0) { category, tips in
                    Section(category) {
                        ForEach(tips) { tip in
                            NavigationLink(value: tip) {
                                tipRow(tip)
                            }
                        }
                    }
                }

                if filteredTips.isEmpty {
                    Section {
                        Text("No tips match your search.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search tips")
            .navigationTitle("Learn")
            .navigationDestination(for: Tip.self) { tip in
                TipDetailView(tip: tip)
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(library.categories, id: \.self) { category in
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

    private func tipRow(_ tip: Tip) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: tip.systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(tip.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LearnView()
}
