import CoreText
import Foundation
import PretextCore
#if canImport(PretextUIKit)
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

@MainActor
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

        func mergedRanges(_ ranges: [NSRange]) -> [NSRange] {
            guard ranges.isEmpty == false else {
                return []
            }

            let sorted = ranges.sorted {
                if $0.location == $1.location {
                    return $0.length < $1.length
                }
                return $0.location < $1.location
            }

            var merged: [NSRange] = []
            for range in sorted {
                guard var last = merged.last else {
                    merged.append(range)
                    continue
                }

                let lastEnd = NSMaxRange(last)
                if range.location <= lastEnd {
                    last.length = max(lastEnd, NSMaxRange(range)) - last.location
                    merged[merged.count - 1] = last
                } else {
                    merged.append(range)
                }
            }

            return merged
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

        execute("url-like-token-keeps-structured-breakpoint-after-mid-line-entry") {
            let prepared = engine.prepare(
                fixtureText("Visit https://example.com/prepared-layouts"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let first = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: 96)
            let second = engine.nextLine(prepared, cursor: first?.end ?? LayoutCursor(), maxWidth: 96)

            try expectEqual(first?.text, "Visit https://", "expected url-like token to keep a structured split after mid-line entry")
            try expectEqual(second?.text, "example.co", "expected continuation to stay on a structured url fragment instead of falling back to the earlier break")
        }

        execute("hashtag-prefers-delimiter-split-when-it-starts-the-line") {
            let prepared = engine.prepare(
                fixtureText("#layout-cache results"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let line = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("#layout-") + 0.25)
            try expectEqual(line?.text, "#layout-", "expected hashtag delimiter split to stay available")
        }

        execute("hashtag-prefers-delimiter-split-after-mid-line-entry") {
            let prepared = engine.prepare(
                fixtureText("Ping #layout-cache before rollout"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let first = engine.nextLine(prepared, cursor: LayoutCursor(), maxWidth: measure("Ping #layout-") + 0.25)

            try expectEqual(first?.text, "Ping #layout-", "expected hashtag delimiter split to stay available after entering mid-line")
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

        execute("single-line-tail-truncation-exposes-visible-range") {
            let prepared = engine.prepare(
                fixtureText("Single-line cards should expose their visible source span when the core engine truncates the tail."),
                sourceID: PreparedTextSourceID("validation-line-limit-single"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            let packet = engine.layoutPacket(
                prepared,
                maxWidth: 108,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 1,
                    lineBreakMode: .truncateTail,
                    lineBreakStrategy: .automatic,
                    alignment: .natural,
                    layoutDirection: .leftToRight
                )
            )

            try expect(packet.lines.count == 1, "expected exactly one visible line")
            try expect(packet.result.isTruncated, "expected single-line layout to report truncation")
            try expect(packet.result.stoppedEarlyAtMaximumNumberOfLines, "expected single-line layout to stop early")
            try expect(packet.lines.first?.isTruncated == true, "expected visible line to carry truncation state")
            try expect(packet.result.visibleSourceUTF16Ranges.count == 1, "expected a single visible source range for tail truncation")
            let mappedRanges = mergedRanges(packet.sourceCoordinateMap.lines.first?.visibleSourceUTF16Ranges ?? [])
            try expect(mappedRanges == packet.result.visibleSourceUTF16Ranges, "expected source coordinate map to preserve the visible range")
        }

        execute("geometry-packet-reuse-stays-separate-from-draw-cache") {
            let geometryEngine = DefaultPreparedTextEngine()
            let prepared = geometryEngine.prepare(
                fixtureText("Geometry packets should service measurement-only flows without populating draw packets."),
                sourceID: PreparedTextSourceID("validation-geometry-only"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            _ = geometryEngine.geometryPacket(
                prepared,
                maxWidth: 160,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: .default
            )
            _ = geometryEngine.geometryPacket(
                prepared,
                maxWidth: 160,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: .default
            )

            let snapshot = geometryEngine.diagnosticsSnapshot()
            try expect(snapshot.geometryPacketReuseCount == 1, "expected one geometry packet reuse")
            try expect(snapshot.geometryPacketCache.currentEntryCount == 1, "expected one cached geometry packet")
            try expect(snapshot.layoutPacketCache.currentEntryCount == 0, "geometry-only path should not populate draw packet cache")
        }

        execute("custom-truncation-token-preserves-visible-range") {
            let prepared = engine.prepare(
                fixtureText("Prepared truncation hooks should expose visible source ranges without inventing editor behavior."),
                sourceID: PreparedTextSourceID("validation-custom-truncation-token"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            let packet = engine.layoutPacket(
                prepared,
                maxWidth: 120,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 1,
                    lineBreakMode: .truncateTail,
                    lineBreakStrategy: .automatic,
                    alignment: .natural,
                    layoutDirection: .leftToRight,
                    truncationToken: PreparedTruncationToken(text: "[more]", attributeBehavior: .plain)
                )
            )

            let line = packet.lines.first
            let visibleRange = packet.result.visibleTextRange
            try expect(packet.result.isTruncated, "expected truncation state for custom token layout")
            try expect(line?.attributedText.string.hasSuffix("[more]") == true, "expected custom truncation token to appear in rendered line")
            try expect(visibleRange != nil, "expected visible text range for truncated line")
            try expect(line?.truncationTokenDisplayUTF16Range != nil, "expected display range for custom truncation token")
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

        execute("url-friendly-line-limit-preserves-structured-breaks") {
            let prepared = engine.prepare(
                fixtureText("https://example.com/prepared-layouts/with/a/long/path/that/needs/structured/breaks"),
                sourceID: PreparedTextSourceID("validation-url-line-limit"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            let packet = engine.layoutPacket(
                prepared,
                maxWidth: measure("https://example.com/") + 0.25,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 1,
                    lineBreakMode: .wordWrap,
                    lineBreakStrategy: .urlFriendly,
                    alignment: .natural,
                    layoutDirection: .leftToRight
                )
            )

            try expect(packet.lines.count == 1, "expected exactly one visible url-heavy line")
            try expect(packet.result.isTruncated, "expected url-heavy finite-line layout to report clipped overflow")
            try expect(packet.lines.first?.attributedText.string == "https://example.com/", "expected url-friendly strategy to preserve a structured breakpoint")
            try expect(packet.result.visibleSourceUTF16Ranges.count == 1, "expected visible source range for the structured url prefix")
        }

        execute("korean-finite-line-truncation-remains-core-owned") {
            let prepared = engine.prepare(
                fixtureText("준비된 텍스트 엔진은 반복되는 카드 요약 폭에서도 유한 줄 수와 잘린 범위를 코어 레이아웃 결과로 직접 노출해야 한다."),
                sourceID: PreparedTextSourceID("validation-korean-line-limit"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            let packet = engine.layoutPacket(
                prepared,
                maxWidth: 116,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 2,
                    lineBreakMode: .truncateTail,
                    lineBreakStrategy: .cjkImproved,
                    alignment: .natural,
                    layoutDirection: .leftToRight
                )
            )

            try expect(packet.lines.count == 2, "expected exactly two visible Korean lines")
            try expect(packet.result.isTruncated, "expected Korean finite-line layout to report truncation")
            try expect(packet.result.stoppedEarlyAtMaximumNumberOfLines, "expected Korean finite-line layout to stop early")
            try expect(packet.result.visibleLineCount == 2, "expected visible line count to remain observable")
            try expect(packet.result.visibleSourceUTF16Ranges.isEmpty == false, "expected visible source ranges for the retained Korean lines")
        }

        execute("attachment-spans-report-placeholder-vs-resolved-state") {
            let registry = PreparedAttachmentRegistry()
            let attachmentID = PreparedAttachmentID("validation-attachment")
            let sourceID = PreparedTextSourceID("validation-attachment-source")
            let engine = DefaultPreparedTextEngine(
                measurer: CachedFramesetterTextMeasurer(),
                attachmentResolver: registry
            )
            let attachment = PreparedTextAttachment(
                reference: PreparedAttachmentReference(
                    id: attachmentID,
                    placeholderBounds: CGRect(x: 0, y: 0, width: 12, height: 10)
                )
            )
            let attributed = NSMutableAttributedString(
                string: "\u{FFFC}",
                attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica" as CFString, 17, nil)]
            )
            attributed.addAttribute(.attachment, value: attachment, range: NSRange(location: 0, length: attributed.length))
            attributed.addAttribute(.preparedAttachmentReference, value: attachment.reference, range: NSRange(location: 0, length: attributed.length))

            let placeholderPrepared = engine.prepare(
                attributed,
                sourceID: sourceID,
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            try expect(placeholderPrepared.attachmentSpans.count == 1, "expected one attachment span in placeholder state")
            try expect(placeholderPrepared.attachmentSpans.first?.isResolved == false, "expected placeholder attachment span to stay unresolved")
            try expect(
                registry.attachmentState(for: attachment.reference) == .placeholder(attachment.reference),
                "expected registry to expose placeholder attachment lifecycle"
            )

            registry.setAttachmentState(
                .resolved(
                    attachment.reference,
                    PreparedResolvedAttachment(
                        bounds: CGRect(x: 0, y: 0, width: 24, height: 16),
                        contentIdentity: "validation@2x"
                    )
                ),
                invalidate: []
            )
            let resolvedPrepared = engine.prepare(
                attributed,
                sourceID: sourceID,
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            try expect(resolvedPrepared.attachmentSpans.first?.isResolved == true, "expected resolved attachment span after registry update")
            try expectEqual(resolvedPrepared.attachmentSpans.first?.resolvedContentIdentity, "validation@2x", "expected resolved content identity")
            try expect(
                registry.attachmentState(for: attachment.reference).resolvedAttachment?.contentIdentity == "validation@2x",
                "expected resolver lifecycle to expose resolved content identity"
            )
            try expect(
                registry.recordedSourceIDs(for: attachmentID).contains(sourceID),
                "expected registry to retain targeted source invalidation usage"
            )
        }

        execute("visible-tokens-follow-truncated-coordinate-map") {
            let attributed = NSMutableAttributedString(
                string: "Visible #first\nHidden @second",
                attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica" as CFString, 17, nil)]
            )
            attributed.addAttribute(.link, value: URL(string: "https://example.com/first")!, range: NSRange(location: 8, length: 6))
            attributed.addAttribute(.link, value: URL(string: "https://example.com/second")!, range: NSRange(location: 22, length: 7))
            let prepared = engine.prepare(
                attributed,
                sourceID: PreparedTextSourceID("validation-visible-token"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            let packet = engine.layoutPacket(
                prepared,
                maxWidth: 220,
                lineHeight: prepared.defaultLineHeight,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 1,
                    lineBreakMode: .truncateTail,
                    lineBreakStrategy: .automatic,
                    alignment: .natural,
                    layoutDirection: .leftToRight
                )
            )

            let visibleTokens = packet.visibleTokens(in: prepared)
            let visibleAnnotations = packet.visibleAnnotations(in: prepared)
            try expect(visibleTokens.map(\.kind) == [.word, .hashtag], "expected only visible first-line tokens to remain")
            try expect(visibleAnnotations.map(\.kind) == [.link, .hashtag], "expected only visible first-line annotations to remain")
        }

        execute("coordinate-map-best-effort-mode-is-explicit") {
            let prepared = engine.prepare(
                fixtureText("One   two"),
                sourceID: PreparedTextSourceID("validation-coordinate-best-effort"),
                options: PreparedTextOptions(whiteSpaceMode: .cssNormal)
            )
            let packet = engine.layoutPacket(
                prepared,
                maxWidth: 220,
                lineHeight: prepared.defaultLineHeight,
                env: .default
            )

            let spans = packet.sourceCoordinateMap.displayedSpans(forSourceUTF16Range: NSRange(location: 0, length: 3))
            let rects = packet.sourceCoordinateMap.displayedRects(forSourceUTF16Range: NSRange(location: 0, length: 3))
            try expect(packet.sourceCoordinateMap.mappingMode == .bestEffort, "expected css-normal mapping to be best-effort")
            try expect(spans.isEmpty == false, "expected best-effort coordinate mapping to still expose display spans")
            try expect(rects.isEmpty == false, "expected best-effort coordinate mapping to still expose visible rects")
            try expect(rects.allSatisfy { $0.isExact == false }, "expected best-effort coordinate rects to remain explicitly inexact")
        }

        execute("coordinate-map-rect-queries-follow-visible-link-geometry") {
            let attributed = NSMutableAttributedString(
                string: "Visible #first\nHidden second link",
                attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica" as CFString, 17, nil)]
            )
            let visibleRange = (attributed.string as NSString).range(of: "#first")
            let hiddenRange = (attributed.string as NSString).range(of: "second link")
            attributed.addAttribute(.link, value: URL(string: "https://example.com/visible")!, range: visibleRange)
            attributed.addAttribute(.link, value: URL(string: "https://example.com/hidden")!, range: hiddenRange)

            let prepared = engine.prepare(
                attributed,
                sourceID: PreparedTextSourceID("validation-coordinate-rects"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let packet = engine.displayLayoutPacket(
                prepared,
                maxWidth: 180,
                lineHeight: prepared.defaultLineHeight,
                containerWidth: 180,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 1,
                    lineBreakMode: .truncateTail,
                    alignment: .left,
                    layoutDirection: .leftToRight
                )
            )

            let visibleLink = packet.visibleAnnotations(in: prepared).first(where: { $0.kind == .link })
            let visibleRects = visibleLink.map(packet.sourceCoordinateMap.displayedRects(for:)) ?? []
            let hiddenRects = packet.sourceCoordinateMap.displayedRects(forSourceUTF16Range: hiddenRange)

            try expect(visibleRects.isEmpty == false, "expected visible link rects from the public coordinate map")
            try expect(hiddenRects.isEmpty == true, "expected hidden link rects to stay excluded after truncation")
            try expect(visibleRects.allSatisfy(\.isExact), "expected visible literal link rects to stay exact")
        }

        execute("rtl-coordinate-map-rect-queries-stay-visible") {
            let attributed = NSMutableAttributedString(
                string: "مرحبا بالعالم",
                attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica" as CFString, 19, nil)]
            )
            let worldRange = (attributed.string as NSString).range(of: "بالعالم")
            attributed.addAttribute(.link, value: URL(string: "https://example.com/world")!, range: worldRange)

            let prepared = engine.prepare(
                attributed,
                sourceID: PreparedTextSourceID("validation-rtl-coordinate-rects"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )
            let packet = engine.displayLayoutPacket(
                prepared,
                maxWidth: 220,
                lineHeight: prepared.defaultLineHeight,
                containerWidth: 220,
                env: .default,
                options: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 1,
                    lineBreakMode: .wordWrap,
                    alignment: .right,
                    layoutDirection: .rightToLeft
                )
            )

            let rects = packet.sourceCoordinateMap.displayedRects(forSourceUTF16Range: worldRange)

            try expect(rects.isEmpty == false, "expected visible rects for right-to-left source ranges")
            try expect(rects.contains { $0.rect.width > 0 }, "expected right-to-left rect query to preserve positive width")
            try expect(rects.allSatisfy(\.isExact), "expected literal right-to-left rect queries to remain exact")
        }

#if canImport(PretextUIKit)
#if canImport(UIKit)
        execute("stage0-adoption-diagnostics-explain-finite-line-exclusion") {
            PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)

            let label = UILabel()
            label.numberOfLines = 2
            label.attributedText = fixtureText("Finite-line UILabels should stay on system truncation semantics during Stage 0 rollout.")

            let diagnostics = PreparedTextLegacySupport.adoptionDiagnostics(for: label)
            try expect(diagnostics.usesPreparedMeasurement == false, "expected finite-line label to stay out of automatic Stage 0 adoption")
            try expect(diagnostics.reason == .finiteLineLimitRequiresStage1, "expected finite-line rollout reason to mention Stage 1")
        }
#endif

        execute("obstacle-layout-exposes-public-visible-structure") {
            let system = PreparedTextSystem(
                measurer: CachedFramesetterTextMeasurer(),
                invalidationCenter: PreparedInvalidationCenter()
            )
            let layouter = PreparedTextObstacleLayouter(textSystem: system)
            let attributed = NSMutableAttributedString(
                string: "Obstacle layout keeps @ops and #prepared readable around an avatar.",
                attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica" as CFString, 17, nil)]
            )
            let hashtagRange = (attributed.string as NSString).range(of: "#prepared")
            attributed.addAttribute(.link, value: URL(string: "https://example.com/prepared")!, range: hashtagRange)

            let prepared = system.prepare(
                attributed,
                sourceID: PreparedTextSourceID("validation-obstacle"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            let result = layouter.layout(
                prepared: prepared,
                in: CGRect(x: 0, y: 0, width: 260, height: 180),
                obstacles: [
                    PreparedObstacle(circle: PreparedTextObstacleCircle(center: CGPoint(x: 170, y: 62), radius: 34)),
                ],
                lineHeight: prepared.defaultLineHeight,
                obstaclePadding: 10,
                minimumSpanWidth: 30
            )

            let map = result.sourceCoordinateMap(in: prepared)
            let visibleTokens = result.visibleTokens(in: prepared)
            let visibleAnnotations = result.visibleAnnotations(in: prepared)
            let hashtag = visibleTokens.first(where: { $0.kind == .hashtag })
            let hashtagRects = hashtag.map { map.displayedRects(for: $0) } ?? []

            try expect(result.fragments.isEmpty == false, "expected obstacle layout to emit visible fragments")
            try expect(result.snapshot.obstacleCount == 1, "expected obstacle snapshot to report the public obstacle count")
            try expect(map.mappingMode == .exact, "expected obstacle layout to preserve exact coordinate mapping for literal whitespace input")
            try expect(visibleTokens.contains(where: { $0.kind == .mention }), "expected visible mention token through obstacle layout")
            try expect(visibleTokens.contains(where: { $0.kind == .hashtag }), "expected visible hashtag token through obstacle layout")
            try expect(visibleAnnotations.contains(where: { $0.kind == .link }), "expected visible link annotation through obstacle layout")
            try expect(hashtagRects.isEmpty == false, "expected obstacle layout to expose visible rects for hashtag tokens")
        }

        execute("rounded-rect-obstacle-layout-exposes-public-visible-structure") {
            let system = PreparedTextSystem(
                measurer: CachedFramesetterTextMeasurer(),
                invalidationCenter: PreparedInvalidationCenter()
            )
            let layouter = PreparedTextObstacleLayouter(textSystem: system)
            let attributed = NSMutableAttributedString(
                string: "Rounded panels keep #prepared and @ops readable while a note block trims the middle rows.",
                attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica" as CFString, 17, nil)]
            )
            let hashtagRange = (attributed.string as NSString).range(of: "#prepared")
            let prepared = system.prepare(
                attributed,
                sourceID: PreparedTextSourceID("validation-rounded-obstacle"),
                options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
            )

            let result = layouter.layout(
                prepared: prepared,
                in: CGRect(x: 0, y: 0, width: 260, height: 180),
                obstacles: [
                    PreparedObstacle(
                        roundedRect: PreparedTextObstacleRoundedRect(
                            rect: CGRect(x: 132, y: 44, width: 88, height: 86),
                            cornerRadius: 20
                        )
                    ),
                ],
                lineHeight: prepared.defaultLineHeight,
                obstaclePadding: 10,
                minimumSpanWidth: 30
            )

            let map = result.sourceCoordinateMap(in: prepared)
            let rects = map.displayedRects(forSourceUTF16Range: hashtagRange)
            try expect(result.fragments.isEmpty == false, "expected rounded-rect obstacle layout to emit visible fragments")
            try expect(result.preparedObstacles.first?.roundedRect != nil, "expected public obstacle result to preserve rounded-rect metadata")
            try expect(result.snapshot.splitRowCount > 0, "expected rounded-rect obstacle to split at least one row")
            try expect(rects.isEmpty == false, "expected coordinate map rects through rounded-rect obstacle layout")
        }
#endif

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

@main
struct PretextValidationCLI {
    @MainActor
    static func main() {
        do {
            let arguments = try ValidationArguments(arguments: CommandLine.arguments)
            let suite = ValidationSuite(mode: arguments.mode)
            try suite.run()
        } catch {
            fputs("Validation failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
