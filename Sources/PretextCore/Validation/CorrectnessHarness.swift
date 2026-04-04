import CoreText
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum CorrectnessFixtureCategory: String, Hashable, Sendable {
    case strict
    case informational
}

public enum BaselineGateDisposition: String, Hashable, Sendable {
    case gate
    case reportOnly
}

public struct CorrectnessFixture: @unchecked Sendable {
    public var id: String
    public var text: NSAttributedString
    public var widths: [CGFloat]
    public var options: PreparedTextOptions
    public var lineHeight: CGFloat
    public var category: CorrectnessFixtureCategory
    public var baselineGateDisposition: BaselineGateDisposition

    public init(
        id: String,
        text: NSAttributedString,
        widths: [CGFloat],
        options: PreparedTextOptions = PreparedTextOptions(),
        lineHeight: CGFloat,
        category: CorrectnessFixtureCategory = .strict,
        baselineGateDisposition: BaselineGateDisposition? = nil
    ) {
        self.id = id
        self.text = text
        self.widths = widths
        self.options = options
        self.lineHeight = lineHeight
        self.category = category
        self.baselineGateDisposition = baselineGateDisposition ?? (category == .strict ? .gate : .reportOnly)
    }
}

public struct BaselineLineSnapshot: Hashable, Sendable {
    public var index: Int
    public var rangeDescription: String
    public var text: String

    public init(index: Int, rangeDescription: String, text: String) {
        self.index = index
        self.rangeDescription = rangeDescription
        self.text = text
    }
}

public struct BaselineSnapshot: Sendable {
    public var baselineName: String
    public var fixtureID: String
    public var width: CGFloat
    public var lineCount: Int
    public var height: CGFloat
    public var lines: [BaselineLineSnapshot]

    public init(
        baselineName: String,
        fixtureID: String,
        width: CGFloat,
        lineCount: Int,
        height: CGFloat,
        lines: [BaselineLineSnapshot]
    ) {
        self.baselineName = baselineName
        self.fixtureID = fixtureID
        self.width = width
        self.lineCount = lineCount
        self.height = height
        self.lines = lines
    }
}

public struct CorrectnessDiff: Hashable {
    public var fixtureID: String
    public var category: CorrectnessFixtureCategory
    public var width: CGFloat
    public var baselineName: String
    public var expectedLineCount: Int
    public var actualLineCount: Int
    public var firstDivergentLineIndex: Int?
    public var expectedRange: String?
    public var actualRange: String?
    public var expectedLineText: String?
    public var actualLineText: String?
    public var previousLineText: String?
    public var nextLineText: String?
    public var expectedHeight: CGFloat
    public var actualHeight: CGFloat
    public var heightDelta: CGFloat
    public var excerpt: String?

    public init(
        fixtureID: String,
        category: CorrectnessFixtureCategory,
        width: CGFloat,
        baselineName: String,
        expectedLineCount: Int,
        actualLineCount: Int,
        firstDivergentLineIndex: Int?,
        expectedRange: String?,
        actualRange: String?,
        expectedLineText: String?,
        actualLineText: String?,
        previousLineText: String?,
        nextLineText: String?,
        expectedHeight: CGFloat,
        actualHeight: CGFloat,
        heightDelta: CGFloat,
        excerpt: String?
    ) {
        self.fixtureID = fixtureID
        self.category = category
        self.width = width
        self.baselineName = baselineName
        self.expectedLineCount = expectedLineCount
        self.actualLineCount = actualLineCount
        self.firstDivergentLineIndex = firstDivergentLineIndex
        self.expectedRange = expectedRange
        self.actualRange = actualRange
        self.expectedLineText = expectedLineText
        self.actualLineText = actualLineText
        self.previousLineText = previousLineText
        self.nextLineText = nextLineText
        self.expectedHeight = expectedHeight
        self.actualHeight = actualHeight
        self.heightDelta = heightDelta
        self.excerpt = excerpt
    }

    public var summaryLine: String {
        let divergentLine = firstDivergentLineIndex.map(String.init) ?? "none"
        let expectedTextPart = expectedLineText ?? "n/a"
        let actualTextPart = actualLineText ?? "n/a"
        return "fixture=\(fixtureID) width=\(width) baseline=\(baselineName) expectedLines=\(expectedLineCount) actualLines=\(actualLineCount) heightDelta=\(heightDelta) divergentLine=\(divergentLine) expected=\(expectedTextPart) actual=\(actualTextPart)"
    }
}

public struct CorrectnessReport {
    public var comparedBaselineNames: [String]
    public var comparisonCount: Int
    public var diffCount: Int
    public var strictDiffCount: Int
    public var informationalDiffCount: Int
    public var diffCountByBaseline: [String: Int]
    public var diffCountByFixture: [String: Int]
    public var worstHeightDelta: CGFloat
    public var diffs: [CorrectnessDiff]

    public init(
        comparedBaselineNames: [String],
        comparisonCount: Int,
        diffCount: Int,
        strictDiffCount: Int,
        informationalDiffCount: Int,
        diffCountByBaseline: [String: Int],
        diffCountByFixture: [String: Int],
        worstHeightDelta: CGFloat,
        diffs: [CorrectnessDiff]
    ) {
        self.comparedBaselineNames = comparedBaselineNames
        self.comparisonCount = comparisonCount
        self.diffCount = diffCount
        self.strictDiffCount = strictDiffCount
        self.informationalDiffCount = informationalDiffCount
        self.diffCountByBaseline = diffCountByBaseline
        self.diffCountByFixture = diffCountByFixture
        self.worstHeightDelta = worstHeightDelta
        self.diffs = diffs
    }

    public var strictDiffs: [CorrectnessDiff] {
        diffs.filter { $0.category == .strict }
    }

    public var informationalDiffs: [CorrectnessDiff] {
        diffs.filter { $0.category == .informational }
    }

    public func strictGateFailures(
        heightThreshold: CGFloat = 1,
        requiredBaselines: Set<String> = []
    ) -> [String] {
        var failures = strictDiffs.compactMap { diff in
            if diff.expectedLineCount != diff.actualLineCount {
                return "\(diff.fixtureID) \(diff.baselineName) width=\(diff.width): line count \(diff.expectedLineCount) != \(diff.actualLineCount)"
            }
            if let firstDivergentLineIndex = diff.firstDivergentLineIndex {
                return "\(diff.fixtureID) \(diff.baselineName) width=\(diff.width): first divergent line \(firstDivergentLineIndex)"
            }
            if diff.heightDelta > heightThreshold {
                return "\(diff.fixtureID) \(diff.baselineName) width=\(diff.width): height delta \(diff.heightDelta) > \(heightThreshold)"
            }
            return nil
        }

        if !requiredBaselines.isEmpty {
            let availableBaselines = Set(comparedBaselineNames)
            for baseline in requiredBaselines.sorted() where !availableBaselines.contains(baseline) {
                failures.append("missing strict baseline coverage for \(baseline)")
            }
        }

        return failures
    }
}

public protocol TextBaselineComparator {
    var name: String { get }
    func snapshot(for fixture: CorrectnessFixture, width: CGFloat) -> BaselineSnapshot
}

public struct CoreTextComparator: TextBaselineComparator {
    public let name = "CoreText"

    public init() {}

    public func snapshot(for fixture: CorrectnessFixture, width: CGFloat) -> BaselineSnapshot {
        let normalizedText = normalizedCoreTextBaselineAttributedText(for: fixture)
        let framesetter = CTFramesetterCreateWithAttributedString(normalizedText as CFAttributedString)
        let path = CGPath(
            rect: CGRect(x: 0, y: 0, width: max(width, 0), height: .greatestFiniteMagnitude),
            transform: nil
        )
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: normalizedText.length),
            path,
            nil
        )
        let lines = extractCoreTextFrameLines(frame: frame, attributedText: normalizedText)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: width, height: .greatestFiniteMagnitude),
            nil
        )
        let normalizedHeight: CGFloat
        if fixture.lineHeight > 0 {
            normalizedHeight = CGFloat(lines.count) * fixture.lineHeight
        } else {
            normalizedHeight = suggestedSize.height
        }

        return BaselineSnapshot(
            baselineName: name,
            fixtureID: fixture.id,
            width: width,
            lineCount: lines.count,
            height: normalizedHeight,
            lines: lines
        )
    }
}

public struct PreparedEngineComparator: TextBaselineComparator {
    public let name = "PreparedEngine"
    private let engine: PreparedTextEngine

    public init(engine: PreparedTextEngine) {
        self.engine = engine
    }

    public func snapshot(for fixture: CorrectnessFixture, width: CGFloat) -> BaselineSnapshot {
        let prepared = engine.prepare(fixture.text, options: fixture.options)
        var lines: [BaselineLineSnapshot] = []
        var cursor = LayoutCursor()
        var lineIndex = 0

        while let line = engine.nextLine(prepared, cursor: cursor, maxWidth: width) {
            lines.append(
                BaselineLineSnapshot(
                    index: lineIndex,
                    rangeDescription: cursorDescription(start: line.start, end: line.end),
                    text: normalizedSnapshotLineText(line.text ?? engine.attributedLine(prepared, line: line).string)
                )
            )
            lineIndex += 1
            cursor = line.end
        }

        let layout = engine.layout(prepared, maxWidth: width, lineHeight: fixture.lineHeight)
        return BaselineSnapshot(
            baselineName: name,
            fixtureID: fixture.id,
            width: width,
            lineCount: layout.lineCount,
            height: layout.height,
            lines: lines
        )
    }

    private func cursorDescription(start: LayoutCursor, end: LayoutCursor) -> String {
        "\(start.segmentIndex):\(start.graphemeIndex)->\(end.segmentIndex):\(end.graphemeIndex)"
    }
}

public final class CorrectnessHarness {
    private let engine: PreparedTextEngine

    public init(engine: PreparedTextEngine) {
        self.engine = engine
    }

    public func compare(fixtures: [CorrectnessFixture], baselines: [TextBaselineComparator]) -> [CorrectnessDiff] {
        compareReport(fixtures: fixtures, baselines: baselines).diffs
    }

    public func compareReport(fixtures: [CorrectnessFixture], baselines: [TextBaselineComparator]) -> CorrectnessReport {
        let preparedComparator = PreparedEngineComparator(engine: engine)
        var diffs: [CorrectnessDiff] = []
        var comparisons = 0

        for fixture in fixtures {
            for width in fixture.widths {
                let actual = preparedComparator.snapshot(for: fixture, width: width)
                for baseline in baselines {
                    comparisons += 1
                    let expected = baseline.snapshot(for: fixture, width: width)
                    if let diff = diff(expected: expected, actual: actual, category: fixture.category) {
                        diffs.append(diff)
                    }
                }
            }
        }

        let baselineCounts = Dictionary(grouping: diffs, by: \.baselineName).mapValues(\.count)
        let fixtureCounts = Dictionary(grouping: diffs, by: \.fixtureID).mapValues(\.count)
        let worstHeightDelta = diffs.map(\.heightDelta).max() ?? 0
        let strictDiffCount = diffs.filter { $0.category == .strict }.count
        let informationalDiffCount = diffs.filter { $0.category == .informational }.count

        return CorrectnessReport(
            comparedBaselineNames: baselines.map(\.name),
            comparisonCount: comparisons,
            diffCount: diffs.count,
            strictDiffCount: strictDiffCount,
            informationalDiffCount: informationalDiffCount,
            diffCountByBaseline: baselineCounts,
            diffCountByFixture: fixtureCounts,
            worstHeightDelta: worstHeightDelta,
            diffs: diffs
        )
    }

    private func diff(
        expected: BaselineSnapshot,
        actual: BaselineSnapshot,
        category: CorrectnessFixtureCategory
    ) -> CorrectnessDiff? {
        let maxCount = max(expected.lines.count, actual.lines.count)
        var firstDivergentLineIndex: Int?
        var expectedRange: String?
        var actualRange: String?
        var expectedLineText: String?
        var actualLineText: String?
        var previousLineText: String?
        var nextLineText: String?
        var excerpt: String?

        for index in 0..<maxCount {
            let lhs = index < expected.lines.count ? expected.lines[index] : nil
            let rhs = index < actual.lines.count ? actual.lines[index] : nil
            if lhs?.text != rhs?.text {
                firstDivergentLineIndex = index
                expectedRange = lhs?.rangeDescription
                actualRange = rhs?.rangeDescription
                expectedLineText = lhs?.text
                actualLineText = rhs?.text
                if index > 0 {
                    previousLineText = actual.lines[safe: index - 1]?.text ?? expected.lines[safe: index - 1]?.text
                }
                nextLineText = actual.lines[safe: index + 1]?.text ?? expected.lines[safe: index + 1]?.text
                excerpt = rhs?.text ?? lhs?.text
                break
            }
        }

        let heightDelta = abs(expected.height - actual.height)
        guard firstDivergentLineIndex != nil || expected.lineCount != actual.lineCount || heightDelta > 0.5 else {
            return nil
        }

        return CorrectnessDiff(
            fixtureID: expected.fixtureID,
            category: category,
            width: expected.width,
            baselineName: expected.baselineName,
            expectedLineCount: expected.lineCount,
            actualLineCount: actual.lineCount,
            firstDivergentLineIndex: firstDivergentLineIndex,
            expectedRange: expectedRange,
            actualRange: actualRange,
            expectedLineText: expectedLineText,
            actualLineText: actualLineText,
            previousLineText: previousLineText,
            nextLineText: nextLineText,
            expectedHeight: expected.height,
            actualHeight: actual.height,
            heightDelta: heightDelta,
            excerpt: excerpt
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }
        return self[index]
    }
}

public func normalizedSnapshotLineText(_ text: String) -> String {
    var normalized = text
    while let last = normalized.last, last == "\n" || last == "\r" || last == "\t" || last == " " {
        normalized.removeLast()
    }
    let endedWithSoftHyphen = normalized.last == "\u{00AD}"
    normalized.removeAll { $0 == "\u{00AD}" || $0 == "\u{200B}" }
    if endedWithSoftHyphen {
        normalized.append("-")
    }
    return normalized
}

private func normalizedCoreTextBaselineAttributedText(for fixture: CorrectnessFixture) -> NSAttributedString {
    let mutable = NSMutableAttributedString(attributedString: fixture.text)
    let fullRange = NSRange(location: 0, length: mutable.length)

    mutable.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
        let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.minimumLineHeight = fixture.lineHeight
        style.maximumLineHeight = fixture.lineHeight
        style.lineSpacing = 0
        mutable.addAttribute(.paragraphStyle, value: style, range: range)
    }

    return mutable
}

private func extractCoreTextFrameLines(frame: CTFrame, attributedText: NSAttributedString) -> [BaselineLineSnapshot] {
    let nsString = attributedText.string as NSString
    let frameLines = CTFrameGetLines(frame) as NSArray

    return frameLines.enumerated().map { index, value in
        let line = value as! CTLine
        let stringRange = CTLineGetStringRange(line)
        let range = NSRange(location: stringRange.location, length: stringRange.length)
        guard range.location != kCFNotFound, NSMaxRange(range) <= nsString.length else {
            return BaselineLineSnapshot(
                index: index,
                rangeDescription: "0..<0",
                text: ""
            )
        }

        return BaselineLineSnapshot(
            index: index,
            rangeDescription: "\(range.location)..<\(range.location + range.length)",
            text: normalizedSnapshotLineText(nsString.substring(with: range))
        )
    }
}
