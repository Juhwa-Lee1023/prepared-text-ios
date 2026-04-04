#if canImport(SwiftUI)
import PretextUIKit
import PretextSwiftUI
import SwiftUI
import UIKit

struct PreparedTextDemoRootView: View {
    @EnvironmentObject private var demoSettings: PreparedTextDemoSettings
    @State private var selectedTab: DemoTab = .patterns

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PreparedTextShowcaseView(language: demoSettings.language)
                    .navigationTitle(localizedTitle(for: .patterns))
                    .toolbar { languageToolbarMenu }
            }
            .tag(DemoTab.patterns)
            .tabItem {
                Label(localizedTabLabel(for: .patterns), systemImage: "text.bubble")
            }

            NavigationStack {
                PreparedTextObstacleShowcaseView(language: demoSettings.language)
                    .navigationTitle(localizedTitle(for: .obstacles))
                    .toolbar { languageToolbarMenu }
            }
            .tag(DemoTab.obstacles)
            .tabItem {
                Label(localizedTabLabel(for: .obstacles), systemImage: "sparkles.rectangle.stack")
            }

            NavigationStack {
                PreparedTextUIKitHostView(language: demoSettings.language)
                    .navigationTitle(localizedTitle(for: .uikit))
                    .toolbar { languageToolbarMenu }
            }
            .tag(DemoTab.uikit)
            .tabItem {
                Label(localizedTabLabel(for: .uikit), systemImage: "rectangle.3.group")
            }
        }
    }

    @ToolbarContentBuilder
    private var languageToolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(PreparedTextDemoLanguage.allCases) { language in
                    Button {
                        demoSettings.language = language
                    } label: {
                        if demoSettings.language == language {
                            Label(language.displayName, systemImage: "checkmark")
                        } else {
                            Text(language.displayName)
                        }
                    }
                }
            } label: {
                Label(localizedLanguageMenuTitle, systemImage: "globe")
            }
        }
    }

    private var localizedLanguageMenuTitle: String {
        switch demoSettings.language {
        case .english:
            return "Language"
        case .korean:
            return "언어"
        case .japanese:
            return "言語"
        case .chineseSimplified:
            return "语言"
        case .chineseTraditional:
            return "語言"
        }
    }

    private func localizedTabLabel(for tab: DemoTab) -> String {
        switch (demoSettings.language, tab) {
        case (.english, .patterns):
            return "Patterns"
        case (.english, .obstacles):
            return "Obstacles"
        case (.english, .uikit):
            return "UIKit"
        case (.korean, .patterns):
            return "패턴"
        case (.korean, .obstacles):
            return "장애물"
        case (.korean, .uikit):
            return "UIKit"
        case (.japanese, .patterns):
            return "パターン"
        case (.japanese, .obstacles):
            return "障害物"
        case (.japanese, .uikit):
            return "UIKit"
        case (.chineseSimplified, .patterns):
            return "模式"
        case (.chineseSimplified, .obstacles):
            return "障碍"
        case (.chineseSimplified, .uikit):
            return "UIKit"
        case (.chineseTraditional, .patterns):
            return "模式"
        case (.chineseTraditional, .obstacles):
            return "障礙"
        case (.chineseTraditional, .uikit):
            return "UIKit"
        }
    }

    private func localizedTitle(for tab: DemoTab) -> String {
        switch (demoSettings.language, tab) {
        case (.english, .patterns):
            return "Surface Patterns"
        case (.english, .obstacles):
            return "Obstacle Flow"
        case (.english, .uikit):
            return "UIKit Lab"
        case (.korean, .patterns):
            return "서피스 패턴"
        case (.korean, .obstacles):
            return "장애물 흐름"
        case (.korean, .uikit):
            return "UIKit 실험실"
        case (.japanese, .patterns):
            return "サーフェスパターン"
        case (.japanese, .obstacles):
            return "障害物フロー"
        case (.japanese, .uikit):
            return "UIKit ラボ"
        case (.chineseSimplified, .patterns):
            return "界面模式"
        case (.chineseSimplified, .obstacles):
            return "障碍物流动"
        case (.chineseSimplified, .uikit):
            return "UIKit 实验室"
        case (.chineseTraditional, .patterns):
            return "介面模式"
        case (.chineseTraditional, .obstacles):
            return "障礙物流動"
        case (.chineseTraditional, .uikit):
            return "UIKit 實驗室"
        }
    }
}

private enum DemoTab: Hashable {
    case patterns
    case obstacles
    case uikit
}

#Preview {
    PreparedTextDemoRootView()
        .environmentObject(PreparedTextDemoSettings(language: .english))
}
#endif
