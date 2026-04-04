import CoreText
import Foundation
import PretextCore

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct BenchmarkFixture {
    let name: String
    let text: NSAttributedString
    let primaryWidth: CGFloat
    let sweepWidths: [CGFloat]
    let options: PreparedTextOptions
    let lineHeight: CGFloat

    init(
        name: String,
        text: NSAttributedString,
        primaryWidth: CGFloat,
        sweepWidths: [CGFloat],
        options: PreparedTextOptions = PreparedTextOptions(),
        lineHeight: CGFloat
    ) {
        self.name = name
        self.text = text
        self.primaryWidth = primaryWidth
        self.sweepWidths = sweepWidths
        self.options = options
        self.lineHeight = lineHeight
    }
}

struct MeasurementPolicyScenario {
    let name: String
    let measurementOptions: PreparedTextMeasurementOptions
    let note: String
}

struct BenchmarkStats {
    let count: Int
    let min: Double
    let median: Double
    let p95: Double
    let max: Double
    let mean: Double
}

struct Stage0WarmSummary {
    let coldMeasure: Double
    let warmMeasure: BenchmarkStats
    let stats: MeasurementStats
}

struct Stage0SweepSummary {
    let timing: BenchmarkStats
    let stats: MeasurementStats
}

struct Stage1SweepSummary {
    let warmPrepare: BenchmarkStats
    let layoutSweep: BenchmarkStats
    let diagnostics: PreparedTextDiagnosticsSnapshot
}

struct ListSizingSummary {
    var totalLines: Int
    var totalHeight: Double
    var totalWidth: Double
}

struct ListSizingScenarioSummary {
    let timing: BenchmarkStats
    let diagnostics: PreparedTextDiagnosticsSnapshot
    let perItemMedian: Double
}

@inline(never)
func consume(_ value: Int) {
    withUnsafePointer(to: value) { pointer in
        _ = pointer
    }
}

@inline(never)
func consume(_ value: Double) {
    withUnsafePointer(to: value) { pointer in
        _ = pointer
    }
}

@inline(never)
func consume(_ value: CGFloat) {
    consume(Double(value))
}

@inline(never)
func consume(_ value: CGSize) {
    consume(value.width)
    consume(value.height)
}

@main
struct PretextBenchmarkCLI {
    static func main() {
        let iterations = envInt("PRETEXT_BENCH_ITERATIONS", default: 24, minimum: 4)
        let sweepRepetitions = envInt("PRETEXT_BENCH_SWEEP_REPETITIONS", default: 12, minimum: 2)
        let listItemCount = envInt("PRETEXT_BENCH_LIST_ITEMS", default: 300, minimum: 24)
        let listBatchRepetitions = envInt("PRETEXT_BENCH_LIST_BATCH_REPETITIONS", default: 5, minimum: 1)

        let fixtures = makeFixtures()
        let policies = makeMeasurementPolicies()
        let listItems = makeListItems(count: listItemCount)

        var lines: [String] = []
        lines.append("# Benchmark Results")
        lines.append("")
        lines.append("- Date: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("- Runtime: host-side SwiftPM CLI on macOS using the prepared-text engine directly")
        lines.append("- Sample iterations: \(iterations)")
        lines.append("- Width sweep repetitions: \(sweepRepetitions)")
        lines.append("- List-style items: \(listItemCount)")
        lines.append("- List batch repetitions: \(listBatchRepetitions)")
        lines.append("")
        lines.append("## Phase 1 Policy Scenarios")
        lines.append("")
        lines.append("- `exact`: exact pixel-width identity, no line-break alignment")
        lines.append("- `bucketed-4pt`: widths are conservatively floored into 4pt buckets before caching")
        lines.append("- `bucketed-4pt-aligned`: widths are first aligned to display scale, then bucketed")
        lines.append("")
        lines.append("Fixtures cover Latin body copy, Korean, Japanese/CJK, emoji-heavy copy, pre-wrap content, long unbroken tokens, long scrolling text, and inline attachments.")
        lines.append("Policy sweeps intentionally use near-identical widths around each fixture's primary width so cache-reuse differences remain measurable.")
        lines.append("")

        lines.append("## Stage 0 Warm Measurement")
        lines.append("")
        lines.append("| Fixture | Cold p50 | Warm p50 | Warm p95 | Hit Rate | Entries | Cost |")
        lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: |")

        for fixture in fixtures {
            let summary = runStage0WarmSummary(
                fixture: fixture,
                iterations: iterations
            )
            lines.append(
                "| \(fixture.name) | \(format(summary.coldMeasure)) | \(format(summary.warmMeasure.median)) | \(format(summary.warmMeasure.p95)) | \(formatPercent(summary.stats.hitRate)) | \(summary.stats.currentEntryCount) | \(summary.stats.currentCost) |"
            )
        }

        lines.append("")
        lines.append("## Stage 0 Repeated-Width Jitter Sweep")
        lines.append("")
        lines.append("| Fixture | Policy | Sweep p50 | Sweep p95 | Hit Rate | Evictions | Entries | Cost |")
        lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")

        for fixture in fixtures {
            for policy in policies {
                let summary = runStage0SweepSummary(
                    fixture: fixture,
                    policy: policy,
                    iterations: iterations,
                    sweepRepetitions: sweepRepetitions
                )
                lines.append(
                    "| \(fixture.name) | \(policy.name) | \(format(summary.timing.median)) | \(format(summary.timing.p95)) | \(formatPercent(summary.stats.hitRate)) | \(summary.stats.evictionCount) | \(summary.stats.currentEntryCount) | \(summary.stats.currentCost) |"
                )
            }
        }

        lines.append("")
        lines.append("## Stage 1 Prepared Layout Reuse")
        lines.append("")
        lines.append("| Fixture | Policy | Warm Prepare p50 | Layout Sweep p50 | Layout Sweep p95 | Layout Hit Rate | Reuse Count | Avg Lines | Cache Cost |")
        lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")

        for fixture in fixtures {
            for policy in policies {
                let summary = runStage1SweepSummary(
                    fixture: fixture,
                    policy: policy,
                    iterations: iterations,
                    sweepRepetitions: sweepRepetitions
                )
                lines.append(
                    "| \(fixture.name) | \(policy.name) | \(format(summary.warmPrepare.median)) | \(format(summary.layoutSweep.median)) | \(format(summary.layoutSweep.p95)) | \(formatPercent(summary.diagnostics.layoutPacketCache.hitRate)) | \(summary.diagnostics.layoutPacketReuseCount) | \(format(summary.diagnostics.averageLinesPerLayout)) | \(summary.diagnostics.layoutPacketCache.currentCost) |"
                )
            }
        }

        lines.append("")
        lines.append("## List-Style Batch Sizing")
        lines.append("")
        lines.append("| Policy | Batch p50 | Batch p95 | Per-Item p50 | Layout Hit Rate | Avg Lines | Notes |")
        lines.append("| --- | ---: | ---: | ---: | ---: | ---: | --- |")

        for policy in policies {
            let summary = runListSizingScenario(
                items: listItems,
                policy: policy,
                iterations: iterations,
                repetitions: listBatchRepetitions
            )
            lines.append(
                "| \(policy.name) | \(format(summary.timing.median)) | \(format(summary.timing.p95)) | \(format(summary.perItemMedian)) | \(formatPercent(summary.diagnostics.layoutPacketCache.hitRate)) | \(format(summary.diagnostics.averageLinesPerLayout)) | \(policy.note) |"
            )
        }

        lines.append("")
        lines.append("## Notes")
        lines.append("")
        lines.append("- `p50` is the median latency per measured operation in milliseconds.")
        lines.append("- Cache cost is an internal bounded estimate used for retention and eviction decisions, not a byte-accurate memory report.")
        lines.append("- `bucketed-*` modes intentionally trade some width precision for better cache reuse on repeated-width self-sizing surfaces.")
        lines.append("- `bucketed-4pt-aligned` is the most aggressive policy here: it aligns fractional proposals to scale before applying the width bucket.")

        print(lines.joined(separator: "\n"))
    }
}

private func runStage0WarmSummary(
    fixture: BenchmarkFixture,
    iterations: Int
) -> Stage0WarmSummary {
    let measurer = CachedFramesetterTextMeasurer()
    let env = MeasurementEnv(
        scale: 2,
        contentSizeCategory: "large",
        localeIdentifier: fixture.options.localeIdentifier
    )
    let sourceID = PreparedTextSourceID("bench-stage0-warm-\(fixture.name)")

    let coldMeasure = timeMilliseconds {
        let size = measurer.measure(fixture.text, sourceID: sourceID, width: fixture.primaryWidth, env: env)
        consume(size)
    }

    _ = measurer.measure(fixture.text, sourceID: sourceID, width: fixture.primaryWidth, env: env)
    let warmMeasure = batchMeasurements(sampleCount: iterations, repetitionsPerSample: 8) {
        let size = measurer.measure(fixture.text, sourceID: sourceID, width: fixture.primaryWidth, env: env)
        consume(size)
    }

    return Stage0WarmSummary(coldMeasure: coldMeasure, warmMeasure: warmMeasure, stats: measurer.stats)
}

private func runStage0SweepSummary(
    fixture: BenchmarkFixture,
    policy: MeasurementPolicyScenario,
    iterations: Int,
    sweepRepetitions: Int
) -> Stage0SweepSummary {
    let measurer = CachedFramesetterTextMeasurer()
    let env = MeasurementEnv(
        scale: 2,
        contentSizeCategory: "large",
        localeIdentifier: fixture.options.localeIdentifier,
        measurementOptions: policy.measurementOptions
    )
    let sourceID = PreparedTextSourceID("bench-stage0-sweep-\(fixture.name)-\(policy.name)")

    let timing = batchMeasurements(sampleCount: iterations, repetitionsPerSample: sweepRepetitions) {
        for width in repeatedWidthJitter(around: fixture.primaryWidth) {
            let size = measurer.measure(fixture.text, sourceID: sourceID, width: width, env: env)
            consume(size)
        }
    }

    return Stage0SweepSummary(timing: timing, stats: measurer.stats)
}

private func runStage1SweepSummary(
    fixture: BenchmarkFixture,
    policy: MeasurementPolicyScenario,
    iterations: Int,
    sweepRepetitions: Int
) -> Stage1SweepSummary {
    let engine = DefaultPreparedTextEngine()
    let sourceID = PreparedTextSourceID("bench-stage1-\(fixture.name)-\(policy.name)")
    let env = MeasurementEnv(
        scale: 2,
        contentSizeCategory: "large",
        localeIdentifier: fixture.options.localeIdentifier,
        measurementOptions: policy.measurementOptions
    )

    _ = engine.prepare(fixture.text, sourceID: sourceID, options: fixture.options)
    let warmPrepare = batchMeasurements(sampleCount: iterations, repetitionsPerSample: 8) {
        let prepared = engine.prepare(fixture.text, sourceID: sourceID, options: fixture.options)
        consume(prepared.defaultLineHeight)
    }

    let prepared = engine.prepare(fixture.text, sourceID: sourceID, options: fixture.options)
    let layoutSweep = batchMeasurements(sampleCount: iterations, repetitionsPerSample: sweepRepetitions) {
        for width in repeatedWidthJitter(around: fixture.primaryWidth) {
            let packet = engine.layoutPacket(
                prepared,
                maxWidth: width,
                lineHeight: fixture.lineHeight,
                env: env
            )
            consume(packet.result.lineCount)
            consume(packet.result.height)
            consume(packet.result.maxPaintWidth)
        }
    }

    return Stage1SweepSummary(
        warmPrepare: warmPrepare,
        layoutSweep: layoutSweep,
        diagnostics: engine.diagnosticsSnapshot()
    )
}

private func runListSizingScenario(
    items: [BenchmarkFixture],
    policy: MeasurementPolicyScenario,
    iterations: Int,
    repetitions: Int
) -> ListSizingScenarioSummary {
    let engine = DefaultPreparedTextEngine()
    let env = MeasurementEnv(
        scale: 2,
        contentSizeCategory: "large",
        measurementOptions: policy.measurementOptions
    )

    let timing = batchMeasurements(sampleCount: iterations, repetitionsPerSample: repetitions) {
        let summary = measureListSizing(engine: engine, items: items, env: env)
        consume(summary.totalLines)
        consume(summary.totalHeight)
        consume(summary.totalWidth)
    }

    return ListSizingScenarioSummary(
        timing: timing,
        diagnostics: engine.diagnosticsSnapshot(),
        perItemMedian: timing.median / Double(max(items.count, 1))
    )
}

private func batchMeasurements(
    sampleCount: Int,
    repetitionsPerSample: Int,
    block: () -> Void
) -> BenchmarkStats {
    precondition(sampleCount > 0)
    precondition(repetitionsPerSample > 0)

    for _ in 0..<2 {
        for _ in 0..<repetitionsPerSample {
            block()
        }
    }

    var samples: [Double] = []
    samples.reserveCapacity(sampleCount)

    for _ in 0..<sampleCount {
        let sample = timeMilliseconds {
            for _ in 0..<repetitionsPerSample {
                block()
            }
        }
        samples.append(sample / Double(repetitionsPerSample))
    }

    return stats(for: samples)
}

private func timeMilliseconds(_ block: () -> Void) -> Double {
    let clock = ContinuousClock()
    let duration = clock.measure {
        block()
    }

    let seconds = Double(duration.components.seconds)
    let attoseconds = Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
    return (seconds + attoseconds) * 1_000
}

private func stats(for samples: [Double]) -> BenchmarkStats {
    let sorted = samples.sorted()
    let count = sorted.count
    let minValue = sorted.first ?? 0
    let maxValue = sorted.last ?? 0
    let meanValue = samples.reduce(0, +) / Double(max(count, 1))
    let medianValue = percentile(sorted, fraction: 0.5)
    let p95Value = percentile(sorted, fraction: 0.95)

    return BenchmarkStats(
        count: count,
        min: minValue,
        median: medianValue,
        p95: p95Value,
        max: maxValue,
        mean: meanValue
    )
}

private func percentile(_ sorted: [Double], fraction: Double) -> Double {
    guard !sorted.isEmpty else {
        return 0
    }

    guard sorted.count > 1 else {
        return sorted[0]
    }

    let clampedFraction = min(max(fraction, 0), 1)
    let index = Int((Double(sorted.count - 1) * clampedFraction).rounded(.up))
    return sorted[min(index, sorted.count - 1)]
}

private func format(_ value: Double) -> String {
    String(format: "%.3f", value)
}

private func formatPercent(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

private func envInt(_ name: String, default defaultValue: Int, minimum: Int) -> Int {
    guard let raw = ProcessInfo.processInfo.environment[name], let value = Int(raw) else {
        return max(defaultValue, minimum)
    }

    return max(value, minimum)
}

private func measureListSizing(
    engine: PreparedTextEngine,
    items: [BenchmarkFixture],
    env: MeasurementEnv
) -> ListSizingSummary {
    var totalLines = 0
    var totalHeight = 0.0
    var totalWidth = 0.0

    for item in items {
        let prepared = engine.prepare(
            item.text,
            sourceID: PreparedTextSourceID(item.name),
            options: item.options
        )
        let result = engine.layout(
            prepared,
            maxWidth: item.primaryWidth,
            lineHeight: item.lineHeight,
            env: env
        )
        totalLines += result.lineCount
        totalHeight += Double(result.height)
        totalWidth += Double(result.maxPaintWidth)
    }

    return ListSizingSummary(totalLines: totalLines, totalHeight: totalHeight, totalWidth: totalWidth)
}

private func makeMeasurementPolicies() -> [MeasurementPolicyScenario] {
    [
        MeasurementPolicyScenario(
            name: "exact",
            measurementOptions: .default,
            note: "Use for width-sensitive surfaces that need strict per-width identity."
        ),
        MeasurementPolicyScenario(
            name: "bucketed-4pt",
            measurementOptions: PreparedTextMeasurementOptions(
                widthNormalizationPolicy: .bucketed(points: 4),
                pixelMeasurementPolicy: .exact
            ),
            note: "Good first opt-in for repeated-width self-sizing loops."
        ),
        MeasurementPolicyScenario(
            name: "bucketed-4pt-aligned",
            measurementOptions: PreparedTextMeasurementOptions(
                widthNormalizationPolicy: .bucketed(points: 4),
                pixelMeasurementPolicy: .alignedToScale
            ),
            note: "Most stable repeated-measurement mode for fractional width churn."
        ),
    ]
}

private func repeatedWidthJitter(around primaryWidth: CGFloat) -> [CGFloat] {
    let base = max(primaryWidth, 24)
    return [
        max(base - 3.4, 1),
        max(base - 1.6, 1),
        max(base - 0.4, 1),
        base + 0.6,
        base + 1.8,
        base + 3.6,
    ]
}

private func makeFixtures() -> [BenchmarkFixture] {
    let font = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
    let attributes: [NSAttributedString.Key: Any] = [kCTFontAttributeName as NSAttributedString.Key: font]

    func text(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: attributes)
    }

    let english = "Prepared text layout should amortize expensive shaping and keep repeated width churn predictable."
    let korean = "준비된 텍스트 레이아웃은 반복적인 너비 변화에서도 측정과 줄바꿈이 안정적으로 재사용되어야 한다."
    let japanese = "日本語の段落も幅の変化ごとに無駄なく再計算され、同じ条件では同じレイアウトを再利用したい。"
    let emoji = "🙂🙂🙂 Emoji-dense reaction summaries should not cause opaque cache churn across slightly changing widths. 🚀✨📦"
    let prewrap = "Tabs\tstay visible\nand soft hy\u{00AD}phens appear only when selected."
    let longToken = "supercalifragilisticexpialidocious-supercalifragilisticexpialidocious-supercalifragilisticexpialidocious"
    let longText = Array(repeating: "Long text sizing should reuse prepared layout work across cards, feeds, and chat transcripts.", count: 14)
        .joined(separator: " ")

    var fixtures = [
        BenchmarkFixture(
            name: "body-english",
            text: text(english),
            primaryWidth: 240,
            sweepWidths: [160, 200, 240, 280, 320, 400],
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "korean-body",
            text: text(korean),
            primaryWidth: 220,
            sweepWidths: [156, 188, 220, 252, 284, 316],
            options: PreparedTextOptions(locale: Locale(identifier: "ko_KR")),
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "japanese-body",
            text: text(japanese),
            primaryWidth: 220,
            sweepWidths: [148, 184, 220, 256, 292],
            options: PreparedTextOptions(locale: Locale(identifier: "ja_JP")),
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "emoji-heavy",
            text: text(emoji),
            primaryWidth: 230,
            sweepWidths: [168, 198, 230, 262, 294],
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "prewrap",
            text: text(prewrap),
            primaryWidth: 220,
            sweepWidths: [160, 192, 220, 252, 284, 320],
            options: PreparedTextOptions(whiteSpaceMode: .preWrap),
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "long-token",
            text: text(longToken),
            primaryWidth: 210,
            sweepWidths: [140, 172, 210, 242, 274],
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "long-text",
            text: text(longText),
            primaryWidth: 320,
            sweepWidths: [240, 280, 320, 360, 420],
            lineHeight: 20
        ),
    ]

    if let attachmentFixture = makeAttachmentFixture(font: font) {
        fixtures.append(attachmentFixture)
    }

    return fixtures
}

private func makeAttachmentFixture(font: CTFont) -> BenchmarkFixture? {
    #if canImport(UIKit) || canImport(AppKit)
    let attributes: [NSAttributedString.Key: Any] = [kCTFontAttributeName as NSAttributedString.Key: font]
    let attachment = NSTextAttachment()
    attachment.bounds = CGRect(x: 0, y: -2, width: 18, height: 14)

    let mutable = NSMutableAttributedString(
        string: "Inline attachment \u{FFFC} should still participate in width-sensitive cache identity.",
        attributes: attributes
    )
    let attachmentRange = (mutable.string as NSString).range(of: "\u{FFFC}")
    if attachmentRange.location != NSNotFound {
        mutable.addAttribute(.attachment, value: attachment, range: attachmentRange)
    }

    return BenchmarkFixture(
        name: "attachment-inline",
        text: mutable,
        primaryWidth: 240,
        sweepWidths: [164, 196, 240, 276, 308],
        lineHeight: 20
    )
    #else
    _ = font
    return nil
    #endif
}

private func makeListItems(count: Int) -> [BenchmarkFixture] {
    let baseItems = makeFixtures()
    var items: [BenchmarkFixture] = []
    items.reserveCapacity(count)

    for index in 0..<count {
        let template = baseItems[index % baseItems.count]
        let widthAdjustment = CGFloat((index % 5) * 12)
        let width = max(160, template.primaryWidth + widthAdjustment - 24)
        items.append(
            BenchmarkFixture(
                name: "list-\(index)",
                text: template.text,
                primaryWidth: width,
                sweepWidths: template.sweepWidths,
                options: template.options,
                lineHeight: template.lineHeight
            )
        )
    }

    return items
}
