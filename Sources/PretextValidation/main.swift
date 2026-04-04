import CoreText
import Foundation
import PretextCore
#if canImport(UIKit) && canImport(PretextUIKit)
import PretextUIKit
#endif

struct ValidationFailure: Error {
    let message: String
}

enum ValidationMode: String {
    case gate
    case report
}

struct ValidationArguments {
    var mode: ValidationMode = .gate

    init(arguments: [String]) throws {
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--mode":
                guard let rawValue = iterator.next(), let parsedMode = ValidationMode(rawValue: rawValue) else {
                    throw ValidationFailure(message: "expected --mode gate|report")
                }
                mode = parsedMode
            case "--gate":
                mode = .gate
            case "--report":
                mode = .report
            case "--help", "-h":
                Self.printUsageAndExit()
            default:
                throw ValidationFailure(message: "unknown argument: \(argument)")
            }
        }
    }

    private static func printUsageAndExit() -> Never {
        print(
            """
            Usage: swift run PretextValidation [--mode gate|report | --gate | --report]

            Modes:
              gate    (--mode gate or --gate)    Run semantic checks and the stable host baseline gate. This is the release path.
              report  (--mode report or --report) Run semantic checks and emit the host baseline report without failing on baseline diffs.
            """
        )
        exit(0)
    }
}

struct HostBaselineGatePolicy {
    var requiredBaselines: Set<String>
    var heightThreshold: CGFloat
}

struct BaselineOutcome {
    var report: CorrectnessReport
    var gateReport: CorrectnessReport
    var gateFailures: [String]
}

struct ValidationSuite {
    private let engine = DefaultPreparedTextEngine()
    private let mode: ValidationMode
    private let hostBaselineGate: HostBaselineGatePolicy

    init(mode: ValidationMode) {
        self.mode = mode
        self.hostBaselineGate = HostBaselineGatePolicy(
            requiredBaselines: ["CoreText"],
            heightThreshold: 1
        )
    }

    func run() throws {
        let semanticOutcome = runSemanticChecks()
        let baselineOutcome = runBaselineChecks()

        print("Validation mode: \(mode.rawValue)")
        print("")
        print(baselineHeader(for: baselineOutcome))
        printBaselineReport(
            baselineOutcome.report,
            gateReport: baselineOutcome.gateReport,
            gatePolicy: hostBaselineGate,
            mode: mode
        )
        print("")
        print(semanticOutcome.results.joined(separator: "\n"))

        var failures = semanticOutcome.failures
        if mode == .gate {
            failures.append(contentsOf: baselineOutcome.gateFailures.map { "strict-host-gate: \($0)" })
        }

        if !failures.isEmpty {
            print("")
            print(failures.map { "FAIL \($0)" }.joined(separator: "\n"))
            throw ValidationFailure(message: "\(failures.count) validation failures")
        }
    }

    private func runSemanticChecks() -> (results: [String], failures: [String]) {
        var results: [String] = []
        var failures: [String] = []

        func execute(_ name: String, _ block: () throws -> Void) {
            do {
                try block()
                results.append("PASS \(name)")
            } catch {
                failures.append("\(name): \(error)")
            }
        }

        execute("stage0-cache-hit") {
            let measurer = CachedFramesetterTextMeasurer()
            let text = fixtureText("Cache me if you can.")
            let env = MeasurementEnv(scale: 2, contentSizeCategory: "large")

            _ = measurer.measure(text, sourceID: PreparedTextSourceID("stage0-cache"), width: 180, env: env)
            _ = measurer.measure(text, sourceID: PreparedTextSourceID("stage0-cache"), width: 180, env: env)
            let stats = measurer.stats

            try expect(stats.hitCount == 1, "expected 1 cache hit, got \(stats.hitCount)")
            try expect(stats.missCount == 1, "expected 1 cache miss, got \(stats.missCount)")
        }

        execute("css-normal-whitespace-collapse") {
            let prepared = engine.prepare(
                fixtureText("One   two"),
                options: PreparedTextOptions(whiteSpaceMode: .cssNormal)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: 500)
            try expectEqual(line?.text, "One two", "collapsed whitespace text mismatch")
        }

        execute("uikit-literal-preserves-hard-break") {
            let prepared = engine.prepare(
                fixtureText("Line 1\nLine 2"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let first = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: 500)
            let second = engine.nextLine(prepared, cursor: first?.end ?? LayoutCursor(), maxWidth: 500)

            try expectEqual(first?.text, "Line 1", "first line mismatch")
            try expectEqual(second?.text, "Line 2", "second line mismatch")
        }

        execute("prewrap-hard-break") {
            let prepared = engine.prepare(
                fixtureText("Line 1\nLine 2"),
                options: PreparedTextOptions(whiteSpaceMode: .preWrap)
            )
            let first = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: 500)
            let second = engine.nextLine(prepared, cursor: first?.end ?? LayoutCursor(), maxWidth: 500)

            try expectEqual(first?.text, "Line 1", "first line mismatch")
            try expectEqual(second?.text, "Line 2", "second line mismatch")
        }

        execute("uikit-literal-trailing-space-fit-vs-paint") {
            let prepared = engine.prepare(
                fixtureText("Tail "),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: 500)
            try expect((line?.width ?? 0) > (line?.paintWidth ?? 0), "expected fit width to exceed paint width")
            try expectEqual(line?.text, "Tail", "trailing space should not paint")
        }

        execute("soft-hyphen-selected-break") {
            let prepared = engine.prepare(
                fixtureText("ab\u{00AD}cd"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let abHyphenWidth = measure("ab-")
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: abHyphenWidth + 0.1)
            try expectEqual(line?.text, "ab-", "soft hyphen should appear only on chosen break")
        }

        execute("break-priority-prefers-prior-legal-break") {
            let prepared = engine.prepare(
                fixtureText("word wraptest"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("word ") + 0.25)
            try expectEqual(line?.text, "word", "expected previous legal break before splitting current token")
        }

        execute("soft-hyphen-prefers-hyphenated-break-when-it-fits") {
            let prepared = engine.prepare(
                fixtureText("and co\u{00AD}operating"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("and co-") + 0.25)
            try expectEqual(line?.text, "and co-", "expected discretionary hyphen break when it fits")
        }

        execute("grapheme-progress") {
            let prepared = engine.prepare(
                fixtureText("abcdefghij"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("ab") + 0.1)
            try expect(line != nil, "expected non-nil first line")
            try expect((line?.end ?? LayoutCursor()) > LayoutCursor(), "expected cursor progress")
        }

        execute("crlf-normalization-across-runs") {
            let mixed = NSMutableAttributedString(
                string: "A\r",
                attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica" as CFString, 17, nil)]
            )
            mixed.append(
                NSAttributedString(
                    string: "\nB",
                    attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica-Bold" as CFString, 17, nil)]
                )
            )

            let prepared = engine.prepare(mixed, options: PreparedTextOptions(whiteSpaceMode: .preWrap))
            let first = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: 500)
            let second = engine.nextLine(prepared, cursor: first?.end ?? LayoutCursor(), maxWidth: 500)
            let third = engine.nextLine(prepared, cursor: second?.end ?? LayoutCursor(), maxWidth: 500)

            try expectEqual(first?.text, "A", "expected first CRLF-normalized line")
            try expectEqual(second?.text, "B", "expected second CRLF-normalized line")
            try expect(third == nil, "expected CRLF pair to become a single hard break")
        }

        execute("nbsp-does-not-create-wrap-point") {
            let prepared = engine.prepare(
                fixtureText("A\u{00A0}B"),
                options: PreparedTextOptions(whiteSpaceMode: .preWrap)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("A\u{00A0}") + 0.1)
            try expectEqual(line?.text, "A\u{00A0}B", "expected NBSP to keep adjacent tokens together")
        }

        execute("soft-hyphen-candidate-must-fit") {
            let prepared = engine.prepare(
                fixtureText("a\u{00AD}bc"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("a") + 0.01)
            try expect((line?.width ?? 0) <= measure("a") + 0.01 + 0.5, "expected chosen soft-hyphen break to fit width")
        }

        execute("url-like-token-is-single-break-unit-until-forced") {
            let token = "https://example.com/prepared-layouts"
            let prepared = engine.prepare(
                fixtureText("See \(token)"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("See ") + 0.25)
            try expectEqual(line?.text, "See", "expected prior legal break before url-like token split")
        }

        execute("url-like-token-keeps-structured-breakpoint-when-it-starts-the-line") {
            let token = "https://example.com/prepared-layouts"
            let prepared = engine.prepare(
                fixtureText(token),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("https://example.com/") + 0.25)
            try expectEqual(line?.text, "https://example.com/", "expected structured delimiter split before grapheme fallback")
        }

        execute("hashtag-prefers-delimiter-split-when-it-starts-the-line") {
            let prepared = engine.prepare(
                fixtureText("#layout-cache results"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("#layout-") + 0.25)
            try expectEqual(line?.text, "#layout-", "expected hashtag delimiter split to stay available")
        }

        execute("line-fragment-height-follows-requested-line-height") {
            let prepared = engine.prepare(
                fixtureText("Prepared layout height should follow the requested line height across rows."),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let result = engine.layout(prepared, maxWidth: 120, lineHeight: 18)

            try expect(result.lineCount > 1, "expected multiline layout")
            try expect(result.fragments.allSatisfy { abs($0.blockAdvance - 18) < 0.01 }, "expected all fragments to use the requested line height")
            try expect(abs(result.height - CGFloat(result.lineCount) * 18) < 0.01, "expected height to sum fragment block advances")
        }

        execute("finite-line-tail-truncation-is-core-owned") {
            let prepared = engine.prepare(
                fixtureText("Feed summaries should stop at the requested line count inside the core layout engine."),
                sourceID: PreparedTextSourceID("validation-line-limit"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            let packet = engine.layoutPacket(
                prepared,
                maxWidth: 92,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 2,
                    lineBreakMode: .truncateTail,
                    lineBreakStrategy: .automatic,
                    alignment: .natural,
                    layoutDirection: .leftToRight
                )
            )

            try expect(packet.lines.count == 2, "expected exactly two visible lines")
            try expect(packet.result.isTruncated, "expected finite-line layout to report truncation")
            try expect(packet.result.stoppedEarlyAtMaximumNumberOfLines, "expected finite-line layout to stop early")
            try expect(packet.lines.last?.isTruncated == true, "expected final visible line to carry truncation state")
        }

        execute("word-wrap-line-limit-still-reports-hidden-overflow") {
            let prepared = engine.prepare(
                fixtureText("Word wrapping with a finite line limit should clip overflow without inventing an ellipsis token."),
                sourceID: PreparedTextSourceID("validation-word-wrap-limit"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            let packet = engine.layoutPacket(
                prepared,
                maxWidth: 100,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 1,
                    lineBreakMode: .wordWrap,
                    lineBreakStrategy: .automatic,
                    alignment: .natural,
                    layoutDirection: .leftToRight
                )
            )

            try expect(packet.result.isTruncated, "expected finite word-wrap layout to report clipped overflow")
            try expect(packet.lines.first?.isTruncated == true, "expected final visible line to report truncation even without an ellipsis")
            try expect(packet.lines.first?.attributedText.string.contains("…") == false, "word-wrap clipping should not inject ellipsis")
        }

        execute("layout-direction-affects-core-alignment-resolution") {
            let prepared = engine.prepare(
                fixtureText("Natural alignment should resolve inside the core packet path."),
                sourceID: PreparedTextSourceID("validation-layout-direction"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            let leftToRight = engine.layoutPacket(
                prepared,
                maxWidth: 140,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 1,
                    lineBreakMode: .truncateTail,
                    lineBreakStrategy: .automatic,
                    alignment: .leading,
                    layoutDirection: .leftToRight
                )
            )
            let rightToLeft = engine.layoutPacket(
                prepared,
                maxWidth: 140,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 1,
                    lineBreakMode: .truncateTail,
                    lineBreakStrategy: .automatic,
                    alignment: .leading,
                    layoutDirection: .rightToLeft
                )
            )

            try expect(leftToRight.lines.first?.resolvedAlignment == .left, "expected LTR leading alignment to resolve left")
            try expect(rightToLeft.lines.first?.resolvedAlignment == .right, "expected RTL leading alignment to resolve right")
        }

        execute("layout-packet-cache-reuse") {
            let prepared = engine.prepare(
                fixtureText("Prepared text handles should reuse cached layout packets for identical widths."),
                sourceID: PreparedTextSourceID("layout-packet-cache"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let first = engine.layoutPacket(prepared, maxWidth: 220, lineHeight: prepared.defaultLineHeight)
            let second = engine.layoutPacket(prepared, maxWidth: 220, lineHeight: prepared.defaultLineHeight)

            try expect(first.result == second.result, "expected cached layout packet to preserve layout result")
            try expect(first.lines.count == second.lines.count, "expected cached layout packet line count reuse")
        }

        return (results, failures)
    }

    private func runBaselineChecks() -> BaselineOutcome {
        let harness = CorrectnessHarness(engine: engine)
        let reportFixtures = CorrectnessFixtureCatalog.defaultCorpus()
        let gateFixtures = CorrectnessFixtureCatalog.baselineGateCorpus()
        let report = harness.compareReport(fixtures: reportFixtures, baselines: baselineComparators())
        let gateReport = harness.compareReport(fixtures: gateFixtures, baselines: [CoreTextComparator()])
        let gateFailures = gateReport.strictGateFailures(
            heightThreshold: hostBaselineGate.heightThreshold,
            requiredBaselines: hostBaselineGate.requiredBaselines
        )
        return BaselineOutcome(report: report, gateReport: gateReport, gateFailures: gateFailures)
    }

    private func baselineHeader(for outcome: BaselineOutcome) -> String {
        switch mode {
        case .gate:
            return "Host baseline threshold gate (\(outcome.gateFailures.isEmpty ? "PASS" : "FAIL"))"
        case .report:
            return "Host baseline report (report-only)"
        }
    }

    private func fixtureText(_ string: String) -> NSAttributedString {
        let font = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
        return NSAttributedString(
            string: string,
            attributes: [kCTFontAttributeName as NSAttributedString.Key: font]
        )
    }

    private func measure(_ string: String) -> CGFloat {
        let font = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
        let attributed = NSAttributedString(
            string: string,
            attributes: [kCTFontAttributeName as NSAttributedString.Key: font]
        )
        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private func expect(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw ValidationFailure(message: message)
        }
    }

    private func expectEqual(_ lhs: String?, _ rhs: String, _ message: String) throws {
        if lhs != rhs {
            throw ValidationFailure(message: "\(message): expected '\(rhs)', got '\(lhs ?? "nil")'")
        }
    }

    private func baselineComparators() -> [TextBaselineComparator] {
        var baselines: [TextBaselineComparator] = [CoreTextComparator()]
#if canImport(UIKit) && canImport(PretextUIKit)
        baselines.append(UILabelComparator())
        baselines.append(UITextViewComparator())
#endif
        return baselines
    }

    private func printBaselineReport(
        _ report: CorrectnessReport,
        gateReport: CorrectnessReport,
        gatePolicy: HostBaselineGatePolicy,
        mode: ValidationMode
    ) {
        let fixtures = CorrectnessFixtureCatalog.defaultCorpus()
        let strictFixtureCount = fixtures.filter { $0.category == .strict }.count
        let informationalFixtureCount = fixtures.filter { $0.category == .informational }.count
        let hostGateFixtureCount = CorrectnessFixtureCatalog.baselineGateCorpus().count

        print("- mode: \(mode.rawValue)")
        print("- strict fixtures: \(strictFixtureCount)")
        print("- informational fixtures: \(informationalFixtureCount)")
        print("- host stable-gate fixtures: \(hostGateFixtureCount)")
        print("- comparisons: \(report.comparisonCount)")
        print("- diffs: \(report.diffCount)")
        print("- strict diffs: \(report.strictDiffCount)")
        print("- informational diffs: \(report.informationalDiffCount)")
        print("- host gate height threshold: \(gatePolicy.heightThreshold)pt")
        print("- worst height delta: \(report.worstHeightDelta)")

        if report.diffCountByBaseline.isEmpty {
            print("- diffs by baseline: none")
        } else {
            let baselineSummary = report.diffCountByBaseline
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            print("- diffs by baseline: \(baselineSummary)")
        }

        if report.diffCountByFixture.isEmpty {
            print("- diffs by fixture: none")
        } else {
            let fixtureSummary = report.diffCountByFixture
                .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
                .prefix(6)
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            print("- top diff fixtures: \(fixtureSummary)")
        }

        if report.strictDiffs.isEmpty {
            print("Strict diff details: no diffs")
        } else {
            print("Strict diff details:")
            for diff in report.strictDiffs.prefix(12) {
                print("- \(diff.summaryLine)")
                if let previousLineText = diff.previousLineText {
                    print("  prev=\(previousLineText)")
                }
                if let nextLineText = diff.nextLineText {
                    print("  next=\(nextLineText)")
                }
            }
        }

        if report.informationalDiffs.isEmpty {
            print("Informational diff details: no diffs")
        } else {
            print("Informational diff details:")
            for diff in report.informationalDiffs.prefix(12) {
                print("- \(diff.summaryLine)")
                if let previousLineText = diff.previousLineText {
                    print("  prev=\(previousLineText)")
                }
                if let nextLineText = diff.nextLineText {
                    print("  next=\(nextLineText)")
                }
            }
        }

        if mode == .gate {
            let failures = gateReport.strictGateFailures(
                heightThreshold: gatePolicy.heightThreshold,
                requiredBaselines: gatePolicy.requiredBaselines
            )
            if failures.isEmpty {
                print("Strict host threshold gate: PASS")
            } else {
                print("Strict host threshold gate: FAIL")
                for failure in failures {
                    print("- \(failure)")
                }
            }
        } else {
            print("Strict host threshold gate is disabled in report mode.")
        }

        print("Strict UIKit baseline gate lives in iOS simulator XCTest with UILabel/UITextView baselines.")
        print("Informational corpus remains report-only in the host CoreText run.")
        print("Host CoreText diffs outside the threshold gate corpus remain report-only, not claimed as zero-diff UIKit parity.")
    }
}

do {
    let arguments = try ValidationArguments(arguments: CommandLine.arguments)
    let suite = ValidationSuite(mode: arguments.mode)
    try suite.run()
} catch {
    fputs("Validation failed: \(error)\n", stderr)
    exit(1)
}
