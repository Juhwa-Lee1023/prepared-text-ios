import CoreText
import Foundation

public enum CorrectnessFixtureCatalog {
    public static func defaultCorpus() -> [CorrectnessFixture] {
        let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
        let boldFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 17, nil)
        let italicFont = CTFontCreateWithName("Helvetica-Oblique" as CFString, 17, nil)
        let serifFont = CTFontCreateWithName("Times-Roman" as CFString, 18, nil)
        let strictLineHeight: CGFloat = 19.6

        let baseAttributes: [NSAttributedString.Key: Any] = [kCTFontAttributeName as NSAttributedString.Key: bodyFont]
        let boldAttributes: [NSAttributedString.Key: Any] = [kCTFontAttributeName as NSAttributedString.Key: boldFont]
        let italicAttributes: [NSAttributedString.Key: Any] = [kCTFontAttributeName as NSAttributedString.Key: italicFont]
        let serifAttributes: [NSAttributedString.Key: Any] = [kCTFontAttributeName as NSAttributedString.Key: serifFont]

        let widths = WidthClass()
        let mixedRuns = NSMutableAttributedString(
            string: "Prepared text ",
            attributes: baseAttributes
        )
        mixedRuns.append(NSAttributedString(string: "bold", attributes: boldAttributes))
        mixedRuns.append(NSAttributedString(string: " and ", attributes: baseAttributes))
        mixedRuns.append(NSAttributedString(string: "italic", attributes: italicAttributes))
        mixedRuns.append(NSAttributedString(string: " runs keep cache keys honest.", attributes: serifAttributes))

        return [
            CorrectnessFixture(
                id: "english-body",
                text: NSAttributedString(string: "Prepared text layout prefers predictable self-sizing.", attributes: baseAttributes),
                widths: [widths.tokenEdge, widths.card, widths.wide],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: strictLineHeight,
                category: .strict
            ),
            CorrectnessFixture(
                id: "url-basic",
                text: NSAttributedString(string: "https://example.com/prepared-layouts keeps rollout notes handy.", attributes: baseAttributes),
                widths: [widths.fractionalNarrow, widths.tokenEdge, widths.card],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: strictLineHeight,
                category: .strict
            ),
            CorrectnessFixture(
                id: "mention-hashtag-basic",
                text: NSAttributedString(string: "Ping @prepared_text and track #layout-cache results.", attributes: baseAttributes),
                widths: [widths.fractionalNarrow, widths.tokenEdge, widths.card],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: strictLineHeight,
                category: .strict
            ),
            CorrectnessFixture(
                id: "nbsp",
                text: NSAttributedString(string: "Keep A\u{00A0}B together while widths shrink.", attributes: baseAttributes),
                widths: [widths.fractionalNarrow, widths.tokenEdge, widths.card],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: strictLineHeight,
                category: .strict
            ),
            CorrectnessFixture(
                id: "prewrap-tabs",
                text: NSAttributedString(string: "Tabs\tstay visible\nand  preserved   spaces remain.\n\nHard breaks keep blank lines.", attributes: baseAttributes),
                widths: [widths.compact, widths.card, widths.wide],
                options: PreparedTextOptions(whiteSpaceMode: .preWrap),
                lineHeight: strictLineHeight,
                category: .strict
            ),
            CorrectnessFixture(
                id: "soft-hyphen",
                text: NSAttributedString(string: "ab\u{00AD}cd", attributes: baseAttributes),
                widths: [widths.hyphenEdge, widths.hyphenNarrow, widths.tokenEdge],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: strictLineHeight,
                category: .strict
            ),
            CorrectnessFixture(
                id: "punctuation-heavy",
                text: NSAttributedString(string: "https://example.com/@pretext?debug=true keeps punctuation-heavy app copy honest.", attributes: baseAttributes),
                widths: [widths.fractionalNarrow, widths.compact, widths.wide],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: 20,
                category: .strict
            ),
            CorrectnessFixture(
                id: "korean-body",
                text: NSAttributedString(string: "준비된 텍스트 레이아웃은 폭이 자주 바뀌는 채팅과 피드에서 높이 예측을 더 안정적으로 만든다.", attributes: baseAttributes),
                widths: [widths.compact, widths.card, widths.wide],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: 21,
                category: .strict
            ),
            CorrectnessFixture(
                id: "japanese-body",
                text: NSAttributedString(string: "日本語の本文でも、幅の提案が何度変わっても再計測を最小化しつつ読みやすい改行を保ちたい。", attributes: baseAttributes),
                widths: [widths.compact, widths.card, widths.tablet],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: 21,
                category: .strict
            ),
            CorrectnessFixture(
                id: "arabic-body",
                text: NSAttributedString(string: "هذا سطر عربي يختبر الترتيب والقياس في واجهات قراءة تعتمد على إعادة تخطيط سريعة.", attributes: baseAttributes),
                widths: [widths.compact, widths.card, widths.wide],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: 24,
                category: .strict
            ),
            CorrectnessFixture(
                id: "mixed-bidi",
                text: NSAttributedString(string: "Ticket 42: العربية meets English, 123, and punctuation -> keep wrap decisions stable.", attributes: baseAttributes),
                widths: [widths.tokenEdge, widths.card, widths.wide],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: 21,
                category: .informational
            ),
            CorrectnessFixture(
                id: "emoji-heavy",
                text: NSAttributedString(string: "Status update 🙂🚀✨ shipped to 3 regions, paging 2 on-call engineers, and keeping emoji width honest.", attributes: baseAttributes),
                widths: [widths.tokenEdge, widths.card, widths.wide],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: 22,
                category: .informational
            ),
            CorrectnessFixture(
                id: "mixed-runs",
                text: mixedRuns,
                widths: [widths.tokenEdge, widths.card, widths.wide],
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
                lineHeight: 22,
                category: .informational
            ),
        ]
    }

    public static func strictCorpus() -> [CorrectnessFixture] {
        defaultCorpus().filter { $0.category == .strict }
    }

    public static func baselineGateCorpus() -> [CorrectnessFixture] {
        defaultCorpus().filter { $0.baselineGateDisposition == .gate }
    }

    public static func simulatorGateCorpus() -> [CorrectnessFixture] {
        let simulatorFixtureIDs: Set<String> = [
            "english-body",
            "url-basic",
            "mention-hashtag-basic",
            "nbsp",
            "prewrap-tabs",
            "soft-hyphen",
        ]
        return defaultCorpus().filter { simulatorFixtureIDs.contains($0.id) }
    }

    public static func informationalCorpus() -> [CorrectnessFixture] {
        defaultCorpus().filter { $0.category == .informational }
    }
}

private struct WidthClass {
    let hyphenEdge: CGFloat = 18
    let hyphenNarrow: CGFloat = 26
    let fractionalNarrow: CGFloat = 72.5
    let tokenEdge: CGFloat = 96
    let compact: CGFloat = 160
    let card: CGFloat = 220
    let wide: CGFloat = 320
    let tablet: CGFloat = 420
}
