#if canImport(SwiftUI)
import Combine
import PretextUIKit
import SwiftUI

@main
struct PreparedTextDemoApp: App {
    @StateObject private var demoSettings = PreparedTextDemoSettings()

    var body: some Scene {
        WindowGroup {
            PreparedTextDemoRootView()
                .environmentObject(demoSettings)
        }
    }
}

@MainActor
final class PreparedTextDemoSettings: ObservableObject {
    @Published var language: PreparedTextDemoLanguage

    init(language: PreparedTextDemoLanguage = .preferred) {
        self.language = language
    }
}
#endif
