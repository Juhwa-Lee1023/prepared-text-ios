#if canImport(UIKit) && !os(macOS)
import Foundation

public enum PreparedTextDemoLanguage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case english = "en"
    case korean = "ko"
    case japanese = "ja"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"

    public var id: String { rawValue }

    public static var preferred: PreparedTextDemoLanguage {
        for identifier in Locale.preferredLanguages {
            if let resolved = from(identifier: identifier) {
                return resolved
            }
        }
        return .english
    }

    public var localeIdentifier: String { rawValue }

    public var displayName: String {
        switch self {
        case .english:
            return "English"
        case .korean:
            return "한국어"
        case .japanese:
            return "日本語"
        case .chineseSimplified:
            return "简体中文"
        case .chineseTraditional:
            return "繁體中文"
        }
    }

    public static func from(identifier: String) -> PreparedTextDemoLanguage? {
        let normalized = identifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        if normalized.hasPrefix("ko") {
            return .korean
        }
        if normalized.hasPrefix("ja") {
            return .japanese
        }
        if normalized.contains("-hans") {
            return .chineseSimplified
        }
        if normalized.contains("-hant") {
            return .chineseTraditional
        }
        if normalized.hasPrefix("zh") && (normalized.contains("-tw") || normalized.contains("-hk") || normalized.contains("-mo")) {
            return .chineseTraditional
        }
        if normalized.hasPrefix("zh") {
            return .chineseSimplified
        }
        if normalized.hasPrefix("en") {
            return .english
        }
        return nil
    }
}
#endif
