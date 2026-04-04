import CoreText
import Foundation
import XCTest
@testable import PretextCore

final class PretextCoreTests: XCTestCase {
    func testCSSNormalCollapsesWhitespace() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("One   two"),
            options: PreparedTextOptions(whiteSpaceMode: .cssNormal)
        )

        let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: 400)
        XCTAssertEqual(line?.text, "One two")
    }

    func testUIKitLiteralPreservesHardBreaks() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("Line 1\nLine 2"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let first = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: 400)
        let second = engine.nextLine(prepared, cursor: first?.end ?? LayoutCursor(), maxWidth: 400)

        XCTAssertEqual(first?.text, "Line 1")
        XCTAssertEqual(second?.text, "Line 2")
    }

    func testBreakPriorityUsesPriorBreakOpportunityBeforeTokenSplit() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("word wraptest"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("word ") + 0.25)
        XCTAssertEqual(line?.text, "word")
    }

    func testNBSPKeepsAdjacentTokensTogether() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("A\u{00A0}B"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("A\u{00A0}") + 0.1)
        XCTAssertEqual(line?.text, "A\u{00A0}B")
    }

    func testSoftHyphenAppearsOnlyOnSelectedBreak() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("ab\u{00AD}cd"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("ab-") + 0.1)
        XCTAssertEqual(line?.text, "ab-")
    }

    func testSoftHyphenBreakCanBeatEarlierWhitespaceWhenHyphenationFits() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("and co\u{00AD}operating"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("and co-") + 0.25)
        XCTAssertEqual(line?.text, "and co-")
    }

    func testLaterExternalBreakBeatsEarlierSoftHyphenCandidate() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("and co\u{00AD}operating notes"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("and cooperating ") + 0.25)
        XCTAssertEqual(line?.text, "and cooperating")
    }

    func testURLLikeTokenRespectsPriorBreakOpportunity() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("See https://example.com/path?q=1"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("See ") + 0.25)
        XCTAssertEqual(line?.text, "See")
    }

    func testURLLikeTokenKeepsStructuredBreakpointWhenItStartsTheLine() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("https://example.com/prepared-layouts"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("https://example.com/") + 0.25)
        XCTAssertEqual(line?.text, "https://example.com/")
    }

    func testURLLikeContinuationUsesWeakAndStrongBreakpointPriorities() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("Visit https://example.com/prepared-layouts"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let first = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: 96)
        let second = engine.nextLine(prepared, cursor: first?.end ?? LayoutCursor(), maxWidth: 96)
        let third = engine.nextLine(prepared, cursor: second?.end ?? LayoutCursor(), maxWidth: 96)

        XCTAssertEqual(first?.text, "Visit")
        XCTAssertEqual(second?.text, "https://")
        XCTAssertEqual(third?.text, "example.co")
    }

    func testHashtagTokenPrefersDelimiterBreakpointWhenItStartsTheLine() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("#layout-cache results"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("#layout-") + 0.25)
        XCTAssertEqual(line?.text, "#layout-")
    }

    func testHyphenatedWordStaysAsSingleWordSegment() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("punctuation-heavy"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        XCTAssertEqual(prepared.storage.core.segments.map(\.string), ["punctuation-heavy"])
        XCTAssertEqual(prepared.storage.core.segments.map(\.kind), [.word])
    }

    func testPunctuationOnlyTokenDoesNotDuplicateSegments() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("()"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        XCTAssertEqual(prepared.storage.core.segments.map(\.string), ["(", ")"])
        XCTAssertEqual(prepared.storage.core.segments.map(\.string).joined(), "()")
    }

    func testTrailingPunctuationWrapDoesNotSkipSplitTail() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("測試文字。"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        var cursor = LayoutCursor()
        var rendered = ""
        var lineCount = 0

        while let line = engine.nextLine(prepared, cursor: cursor, maxWidth: 36) {
            rendered.append(line.text ?? "")
            cursor = line.end
            lineCount += 1
            XCTAssertLessThan(lineCount, 8)
        }

        XCTAssertEqual(rendered, "測試文字。")
    }

    func testSoftHyphenNormalizationUsesRenderedHyphen() {
        XCTAssertEqual(normalizedSnapshotLineText("hy\u{00AD}"), "hy-")
        XCTAssertEqual(normalizedSnapshotLineText("hy\u{00AD}phenation"), "hyphenation")
    }

    func testStage0CacheHit() {
        let measurer = CachedFramesetterTextMeasurer()
        let env = MeasurementEnv(scale: 2, contentSizeCategory: "large")
        let attributed = text("Cache me")

        _ = measurer.measure(attributed, sourceID: PreparedTextSourceID("stage0-hit"), width: 180, env: env)
        _ = measurer.measure(attributed, sourceID: PreparedTextSourceID("stage0-hit"), width: 180, env: env)

        XCTAssertEqual(measurer.stats.hitCount, 1)
        XCTAssertEqual(measurer.stats.missCount, 1)
    }

    func testStage0SourceIDRejectsStaleContent() {
        let measurer = CachedFramesetterTextMeasurer()
        let env = MeasurementEnv(scale: 2, contentSizeCategory: "large")
        let sourceID = PreparedTextSourceID("stage0-stale")

        let first = NSMutableAttributedString(attributedString: text("Short"))
        let firstSize = measurer.measure(first, sourceID: sourceID, width: 80, env: env)
        first.append(text(" text that is much longer"))
        let secondSize = measurer.measure(first, sourceID: sourceID, width: 80, env: env)

        XCTAssertGreaterThan(secondSize.height, firstSize.height)
    }

    func testLayoutPacketCacheReusePreservesLayout() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("Prepared text handles should reuse cached layout packets."),
            sourceID: PreparedTextSourceID("layout-cache"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let first = engine.layoutPacket(prepared, maxWidth: 220, lineHeight: prepared.defaultLineHeight)
        let second = engine.layoutPacket(prepared, maxWidth: 220, lineHeight: prepared.defaultLineHeight)

        XCTAssertEqual(first.result, second.result)
        XCTAssertEqual(first.lines.count, second.lines.count)
    }

    func testExplicitLineHeightControlsFragmentBlockAdvance() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("Prepared layout height should follow the requested line height across multiple rows."),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let result = engine.layout(prepared, maxWidth: 120, lineHeight: 18)

        XCTAssertGreaterThan(result.lineCount, 1)
        XCTAssertTrue(result.fragments.allSatisfy { abs($0.blockAdvance - 18) < 0.01 })
        XCTAssertEqual(result.height, CGFloat(result.lineCount) * 18, accuracy: 0.01)
    }

    func testLineFragmentTracksTrailingWhitespaceFitAndPaintWidths() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("Tail "),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        let result = engine.layout(prepared, maxWidth: 300, lineHeight: prepared.defaultLineHeight)
        let fragment = try? XCTUnwrap(result.fragments.first)

        XCTAssertNotNil(fragment)
        XCTAssertGreaterThan(fragment?.fitWidth ?? 0, fragment?.paintWidth ?? 0)
        XCTAssertEqual(
            fragment?.trailingWhitespaceWidth ?? 0,
            (fragment?.fitWidth ?? 0) - (fragment?.paintWidth ?? 0),
            accuracy: 0.01
        )
    }

    func testPrepareSourceIDRejectsStaleContent() {
        let engine = DefaultPreparedTextEngine()
        let sourceID = PreparedTextSourceID("prepare-stale")

        let first = engine.prepare(
            text("Original body"),
            sourceID: sourceID,
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )
        let second = engine.prepare(
            text("Updated body that should not reuse stale prepared output"),
            sourceID: sourceID,
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        XCTAssertNotEqual(first.source.string, second.source.string)
    }

    func testCSSNormalDisablesNativeLineBreakingWhenCoordinateSpaceChanges() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("مرحبا   world"),
            options: PreparedTextOptions(whiteSpaceMode: .cssNormal)
        )

        XCTAssertFalse(prepared.storage.core.prefersNativeLineBreaking)
    }

    func testNativeLineBreakingNormalizesTabStopsBeforeCreatingTypesetter() {
        let engine = DefaultPreparedTextEngine()
        let prepared = engine.prepare(
            text("🙂\tcolumn"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )

        XCTAssertTrue(prepared.storage.core.prefersNativeLineBreaking)
        let nativeSource = try? XCTUnwrap(prepared.storage.nativeLineBreakingSource)
        XCTAssertNotNil(nativeSource)

        let paragraphStyle = nativeSource?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.defaultTabInterval ?? 0, prepared.storage.core.tabStopAdvance, accuracy: 0.01)
        XCTAssertNotNil(prepared.storage.nativeTypesetter)
    }

    func testStrictGateAllowsHeightOnlyDiffWithinThreshold() {
        let report = CorrectnessReport(
            comparedBaselineNames: ["CoreText"],
            comparisonCount: 1,
            diffCount: 1,
            strictDiffCount: 1,
            informationalDiffCount: 0,
            diffCountByBaseline: ["CoreText": 1],
            diffCountByFixture: ["english-body": 1],
            worstHeightDelta: 2,
            diffs: [
                CorrectnessDiff(
                    fixtureID: "english-body",
                    category: .strict,
                    width: 96,
                    baselineName: "CoreText",
                    expectedLineCount: 5,
                    actualLineCount: 5,
                    firstDivergentLineIndex: nil,
                    expectedRange: nil,
                    actualRange: nil,
                    expectedLineText: nil,
                    actualLineText: nil,
                    previousLineText: nil,
                    nextLineText: nil,
                    expectedHeight: 100,
                    actualHeight: 102,
                    heightDelta: 2,
                    excerpt: nil
                ),
            ]
        )

        XCTAssertTrue(
            report.strictGateFailures(heightThreshold: 2, requiredBaselines: ["CoreText"]).isEmpty
        )
    }

    func testStrictGateRejectsUnexpectedDivergentLine() {
        let report = CorrectnessReport(
            comparedBaselineNames: ["CoreText"],
            comparisonCount: 1,
            diffCount: 1,
            strictDiffCount: 1,
            informationalDiffCount: 0,
            diffCountByBaseline: ["CoreText": 1],
            diffCountByFixture: ["english-body": 1],
            worstHeightDelta: 2,
            diffs: [
                CorrectnessDiff(
                    fixtureID: "english-body",
                    category: .strict,
                    width: 96,
                    baselineName: "CoreText",
                    expectedLineCount: 5,
                    actualLineCount: 5,
                    firstDivergentLineIndex: 1,
                    expectedRange: nil,
                    actualRange: nil,
                    expectedLineText: "Prepared",
                    actualLineText: "Prepare",
                    previousLineText: nil,
                    nextLineText: nil,
                    expectedHeight: 100,
                    actualHeight: 102,
                    heightDelta: 2,
                    excerpt: nil
                ),
            ]
        )

        XCTAssertFalse(
            report.strictGateFailures(heightThreshold: 2, requiredBaselines: ["CoreText"]).isEmpty
        )
    }

    func testInformationalCorpusMaintainsCursorProgress() {
        let engine = DefaultPreparedTextEngine()

        for fixture in CorrectnessFixtureCatalog.informationalCorpus() {
            let prepared = engine.prepare(fixture.text, options: fixture.options)

            for width in fixture.widths {
                var cursor = LayoutCursor()
                var lineCount = 0

                while let line = engine.nextLine(prepared, cursor: cursor, maxWidth: width) {
                    XCTAssertGreaterThan(line.end, cursor, "fixture \(fixture.id) must advance cursor")
                    cursor = line.end
                    lineCount += 1
                    XCTAssertLessThan(lineCount, 256, "fixture \(fixture.id) produced suspiciously many lines")
                }

                let layout = engine.layout(prepared, maxWidth: width, lineHeight: fixture.lineHeight)
                XCTAssertEqual(layout.lineCount, lineCount, "fixture \(fixture.id) line count mismatch")
                XCTAssertGreaterThanOrEqual(layout.height, 0, "fixture \(fixture.id) height must stay non-negative")
            }
        }
    }

    func testReadmesAdvertiseTheRealAdoptionAPI() throws {
        let english = try readRepositoryFile("README.md")
        let korean = try readRepositoryFile("README.ko.md")

        [
            "PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)",
            "UILabel().prepared()",
            "MeasurementCachingLabel().prepared(sourceID:",
            "PreparedLabelView().prepared(",
            "\"Hello\".prepared()",
            "AttributedString(\"Hello\").prepared()",
            "NSAttributedString(string: \"Hello\").prepared()",
            "PreparedCopy(\"Hello\"",
            "Text(\"Hello\").prepared(source: \"Hello\")",
            "Text(verbatim: raw).prepared(source: raw)",
        ].forEach { snippet in
            XCTAssertTrue(english.contains(snippet), "README.md missing \(snippet)")
            XCTAssertTrue(korean.contains(snippet), "README.ko.md missing \(snippet)")
        }
    }

    func testReadmesExplicitlyFenceTextPreparedSupport() throws {
        let english = try readRepositoryFile("README.md")
        let korean = try readRepositoryFile("README.ko.md")

        XCTAssertTrue(english.contains("This API is experimental convenience syntax only."))
        XCTAssertTrue(english.contains("the `source` argument is authoritative"))
        XCTAssertTrue(english.contains("the `Text` receiver is not introspected"))
        XCTAssertTrue(english.contains("Zero-argument `Text.prepared()` is still not supported"))

        XCTAssertTrue(korean.contains("이 API는 convenience syntax를 위한 experimental wrapper일 뿐입니다."))
        XCTAssertTrue(korean.contains("`source` 인자가 실제 prepared renderer에 들어가는 authoritative payload입니다"))
        XCTAssertTrue(korean.contains("`Text` receiver 자체는 introspect하지 않습니다"))
        XCTAssertTrue(korean.contains("zero-arg `Text.prepared()`는 여전히 지원하지 않습니다"))
    }

    func testDocsDescribeExperimentalTextPreparedAsSourceDrivenOnly() throws {
        let migrationGuide = try readRepositoryFile("docs/MigrationGuide.md")
        let knownGaps = try readRepositoryFile("docs/KnownGaps.md")

        XCTAssertTrue(migrationGuide.contains("experimental `Text.prepared(source:)`"))
        XCTAssertTrue(migrationGuide.contains("zero-arg `Text.prepared()` 는 지원하지 않는다"))
        XCTAssertTrue(knownGaps.contains("Experimental `Text.prepared(source:)` is syntax sugar only"))
    }

    func testExperimentalTextPreparedSupportStaysSourceDrivenAndNonReflective() throws {
        let experimentalSource = try readRepositoryFile("Sources/PretextSwiftUI/Adoption/PreparedTextExperimentalSugar.swift")
        let swiftUISource = try readRepositoryDirectory("Sources/PretextSwiftUI")

        XCTAssertTrue(experimentalSource.contains("extension Text"))
        XCTAssertTrue(experimentalSource.contains("The `source` parameter is authoritative"))
        XCTAssertTrue(experimentalSource.contains("The `Text` receiver is not introspected"))
        XCTAssertFalse(experimentalSource.contains("Mirror("))
        XCTAssertFalse(experimentalSource.contains("reflecting:"))
        XCTAssertFalse(experimentalSource.contains("CustomReflectable"))
        XCTAssertFalse(experimentalSource.contains("_forEachField"))
        XCTAssertFalse(experimentalSource.contains("func prepared()"))

        let overloadCount = regexMatchCount(
            pattern: #"func\s+prepared\s*\(\s*source:"#,
            in: experimentalSource
        )
        XCTAssertEqual(overloadCount, 4)

        XCTAssertEqual(
            regexMatchCount(pattern: #"extension\s+Text\b"#, in: swiftUISource),
            1,
            "SwiftUI source should expose exactly one Text extension surface for prepared rendering sugar"
        )
        XCTAssertEqual(
            regexMatchCount(pattern: #"func\s+prepared\s*\(\s*\)"#, in: swiftUISource),
            0,
            "zero-argument Text.prepared() must stay unavailable"
        )
        XCTAssertEqual(
            regexMatchCount(pattern: #"Mirror\s*\("#, in: swiftUISource),
            0,
            "SwiftUI source should not rely on reflection for Text.prepared(source:)"
        )
        XCTAssertEqual(
            regexMatchCount(pattern: #"reflecting:"#, in: swiftUISource),
            0,
            "SwiftUI source should not rely on reflection for Text.prepared(source:)"
        )
    }

    private func text(_ string: String) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica" as CFString, 17, nil)]
        )
    }

    private func measure(_ string: String) -> CGFloat {
        let attributed = text(string)
        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private func readRepositoryFile(_ path: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(path), encoding: .utf8)
    }

    private func readRepositoryDirectory(_ path: String) throws -> String {
        let directory = repositoryRoot().appendingPathComponent(path, isDirectory: true)
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)

        var files: [URL] = []
        while let element = enumerator?.nextObject() {
            guard let url = element as? URL, url.pathExtension == "swift" else {
                continue
            }
            files.append(url)
        }

        let sortedFiles = files.sorted { lhs, rhs in
            lhs.path < rhs.path
        }

        return try sortedFiles.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }

    private func regexMatchCount(pattern: String, in text: String) -> Int {
        let expression = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        return expression.numberOfMatches(in: text, range: range)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
