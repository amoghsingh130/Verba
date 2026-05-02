import Foundation

struct Tip: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let summary: String
    let systemImage: String
    let body: String
    let drills: [String]
}

struct TipLibrary {
    static let shared = TipLibrary()

    let tips: [Tip]

    private init() {
        guard let url = Bundle.main.url(forResource: "tips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Tip].self, from: data)
        else {
            tips = []
            return
        }
        tips = decoded
    }

    var categories: [String] {
        let order = ["Frameworks", "Technique", "Delivery", "Mindset", "Scenarios"]
        let present = Set(tips.map(\.category))
        return order.filter { present.contains($0) }
    }
}
