import SwiftUI

struct TipDetailView: View {
    let tip: Tip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(parsedBlocks(from: tip.body), id: \.self) { block in
                    blockView(block)
                }

                if !tip.drills.isEmpty {
                    drillsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: tip.systemImage)
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.category.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(tip.title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }

            Text(tip.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private var drillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().padding(.vertical, 8)
            drillsHeader
            ForEach(Array(tip.drills.enumerated()), id: \.offset) { index, drill in
                drillRow(index: index, text: drill)
            }
        }
    }

    private var drillsHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(Theme.improve)
            Text("Try This")
                .font(.headline)
        }
    }

    private func drillRow(index: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            drillNumber(index + 1)
            Text(.init(text))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.improve.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func drillNumber(_ n: Int) -> some View {
        Text("\(n)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Theme.improve)
            .clipShape(Circle())
    }

    // MARK: - Markdown rendering

    enum Block: Hashable {
        case heading(String)
        case paragraph(String)
        case bullet(String)
        case quote(String)
    }

    private func parsedBlocks(from markdown: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph = ""

        func flushParagraph() {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                blocks.append(.paragraph(trimmed))
            }
            paragraph = ""
        }

        let lines = markdown.components(separatedBy: "\n")
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
            } else if line.hasPrefix("## ") {
                flushParagraph()
                blocks.append(.heading(String(line.dropFirst(3))))
            } else if line.hasPrefix("- ") {
                flushParagraph()
                blocks.append(.bullet(String(line.dropFirst(2))))
            } else if line.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.quote(String(line.dropFirst(2))))
            } else if line.hasPrefix(">") {
                flushParagraph()
                blocks.append(.quote(String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
            } else {
                if !paragraph.isEmpty { paragraph += " " }
                paragraph += line
            }
        }
        flushParagraph()
        return blocks
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let text):
            Text(text)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 8)
        case .paragraph(let text):
            Text(.init(text))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(.init(text))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(width: 3)
                Text(.init(text))
                    .font(.body)
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
        }
    }
}
