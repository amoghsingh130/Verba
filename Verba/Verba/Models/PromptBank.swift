import Foundation

struct SpeechPrompt: Codable, Identifiable {
    var id: String { text }
    let text: String
    let category: String
    let difficulty: String
}

struct PromptBank {
    static let shared = PromptBank()

    let prompts: [SpeechPrompt]

    private init() {
        guard let url = Bundle.main.url(forResource: "prompts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SpeechPrompt].self, from: data)
        else {
            prompts = []
            return
        }
        prompts = decoded
    }

    func random(category: String? = nil) -> SpeechPrompt? {
        let pool = category.map { cat in prompts.filter { $0.category == cat } } ?? prompts
        return pool.randomElement()
    }

    var categories: [String] {
        Array(Set(prompts.map(\.category))).sorted()
    }
}
