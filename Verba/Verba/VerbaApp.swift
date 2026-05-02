import SwiftUI
import SwiftData

@main
struct VerbaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: SpeechSession.self)
    }
}
