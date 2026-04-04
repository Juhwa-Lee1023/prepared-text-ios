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

struct BenchmarkPolicy {
    let name: String
    let env: MeasurementEnv

    init(name: String, env: MeasurementEnv) {
        self.name = name
        self.env = env
    }
}

struct BenchmarkStats {
    let count: Int
    let min: Double
    let median: Double
    let p95: Double
    let max: Double
    let mean: Double
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
        let listItems = makeListItems(count: listItemCount)
        let policies = makePolicies()
        let lineLimitedLayoutOptions = PreparedTextLayoutOptions(
            maximumNumberOfLines: 2,
            lineBreakMode: .truncateTail,
            lineBreakStrategy: .automatic,
            alignment: .natural,
            layoutDirection: .leftToRight
        )

        var lines: [String] = []
        lines.append("# Benchmark Results")
        lines.append("")
        lines.append("- Date: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("- Runtime: host-side SwiftPM CLI on macOS (CoreText-only benchmark path)")
        lines.append("- Sample iterations: \(iterations)")
        lines.append("- Width sweep repetitions: \(sweepRepetitions)")
        lines.append("- List-style items: \(listItemCount)")
        lines.append("- List batch repetitions: \(listBatchRepetitions)")
        lines.append("- Width policies: \(policies.map(\.name).joined(separator: ", "))")
        lines.append("- Corpus: \(fixtures.map(\.name).joined(separator: ", "))")
        lines.append("")

        lines.append("## Stage 0 Width Policy Sweep")
        lines.append("")
        lines.append("| Fixture | Policy | Sweep Median | Sweep p95 | Hit Rate | Misses | Cache Cost |")
        lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: |")

        for fixture in fixtures {
            for policy in policies {
                let measurer = CachedFramesetterTextMeasurer()
                let widths = jitteredWidths(from: fixture.sweepWidths)
                _ = sweepMeasurements(
                    sampleCount: 1,
                    widths: widths,
                    repetitionsPerSample: 1
                ) {
                    for width in widths {
                        let size = measurer.measure(
                            fixture.text,
                            sourceID: PreparedTextSourceID("bench-stage0-\(fixture.name)-\(policy.name)"),
                            width: width,
                            env: policy.env
                        )
                        consume(size)
                    }
                }
                let sweep = sweepMeasurements(
                    sampleCount: iterations,
                    widths: widths,
                    repetitionsPerSample: sweepRepetitions
                ) {
                    for width in widths {
                        let size = measurer.measure(
                            fixture.text,
                            sourceID: PreparedTextSourceID("bench-stage0-\(fixture.name)-\(policy.name)"),
                            width: width,
                            env: policy.env
                        )
                        consume(size)
                    }
                }
                let snapshot = measurer.stats
                lines.append(
                    "| \(fixture.name) | \(policy.name) | \(format(sweep.median)) | \(format(sweep.p95)) | \(percent(snapshot.hitRate)) | \(snapshot.missCount) | \(snapshot.currentCost) |"
                )
            }
        }

        lines.append("")
        lines.append("## Core Finite-Line Layout Reuse")
        lines.append("")
        lines.append("| Fixture | Policy | Sweep Median | Sweep p95 | Layout Cache Hit Rate | Reuse Count | Cache Cost | Avg Lines |")
        lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")

        for fixture in fixtures {
            for policy in policies {
                let engine = DefaultPreparedTextEngine()
                let prepared = engine.prepare(
                    fixture.text,
                    sourceID: PreparedTextSourceID("bench-stage1-\(fixture.name)-\(policy.name)"),
                    options: fixture.options
                )
                let widths = jitteredWidths(from: fixture.sweepWidths)
                _ = sweepMeasurements(
                    sampleCount: 1,
                    widths: widths,
                    repetitionsPerSample: 1
                ) {
                    for width in widths {
                        let packet = engine.layoutPacket(
                            prepared,
                            maxWidth: width,
                            lineHeight: fixture.lineHeight,
                            env: policy.env,
                            options: lineLimitedLayoutOptions
                        )
                        consume(packet.result.lineCount)
                        consume(packet.result.height)
                    }
                }
                let sweep = sweepMeasurements(
                    sampleCount: iterations,
                    widths: widths,
                    repetitionsPerSample: sweepRepetitions
                ) {
                    for width in widths {
                        let packet = engine.layoutPacket(
                            prepared,
                            maxWidth: width,
                            lineHeight: fixture.lineHeight,
                            env: policy.env,
                            options: lineLimitedLayoutOptions
                        )
                        consume(packet.result.lineCount)
                        consume(packet.result.height)
                    }
                }
                let diagnostics = engine.diagnosticsSnapshot()
                lines.append(
                    "| \(fixture.name) | \(policy.name) | \(format(sweep.median)) | \(format(sweep.p95)) | \(percent(diagnostics.layoutPacketCache.hitRate)) | \(diagnostics.layoutPacketReuseCount) | \(diagnostics.layoutPacketCache.currentCost) | \(format(diagnostics.averageLinesPerLayout)) |"
                )
            }
        }

        lines.append("")
        lines.append("## URL Strategy Sweep")
        lines.append("")
        lines.append("| Strategy | Sweep Median | Sweep p95 | Layout Cache Hit Rate | Avg Lines | Notes |")
        lines.append("| --- | ---: | ---: | ---: | ---: | --- |")

        if let urlFixture = fixtures.first(where: { $0.name == "long-token" }) {
            let strategies: [(name: String, value: PreparedTextLineBreakStrategy)] = [
                ("automatic", .automatic),
                ("url-friendly", .urlFriendly),
                ("native-typesetter", .nativeTypesetterPreferred),
            ]
            let exactEnv = policies.first(where: { $0.name == "exact" })?.env ?? .default

            for strategy in strategies {
                let engine = DefaultPreparedTextEngine()
                let prepared = engine.prepare(
                    urlFixture.text,
                    sourceID: PreparedTextSourceID("bench-strategy-\(strategy.name)"),
                    options: urlFixture.options
                )
                let widths = jitteredWidths(from: urlFixture.sweepWidths)
                let sweep = sweepMeasurements(
                    sampleCount: iterations,
                    widths: widths,
                    repetitionsPerSample: sweepRepetitions
                ) {
                    for width in widths {
                        let packet = engine.layoutPacket(
                            prepared,
                            maxWidth: width,
                            lineHeight: urlFixture.lineHeight,
                            env: exactEnv,
                            options: PreparedTextLayoutOptions(
                                maximumNumberOfLines: 2,
                                lineBreakMode: .wordWrap,
                                lineBreakStrategy: strategy.value,
                                alignment: .natural,
                                layoutDirection: .leftToRight
                            )
                        )
                        consume(packet.result.lineCount)
                        consume(packet.result.height)
                        consume(packet.result.maxPaintWidth)
                    }
                }
                let diagnostics = engine.diagnosticsSnapshot()
                lines.append(
                    "| \(strategy.name) | \(format(sweep.median)) | \(format(sweep.p95)) | \(percent(diagnostics.layoutPacketCache.hitRate)) | \(format(diagnostics.averageLinesPerLayout)) | url-heavy 2-line summary path |"
                )
            }
        }

        lines.append("")
        lines.append("## List Sizing Batch")
        lines.append("")
        lines.append("| Policy | Batch Median | Batch p95 | Per-Item Median | Layout Cache Hit Rate | Notes |")
        lines.append("| --- | ---: | ---: | ---: | ---: | --- |")

        for policy in policies {
            let engine = DefaultPreparedTextEngine()
            let batch = batchMeasurements(
                sampleCount: iterations,
                repetitionsPerSample: listBatchRepetitions
            ) {
                let summary = measureListSizing(
                    engine: engine,
                    items: listItems,
                    env: policy.env,
                    layoutOptions: lineLimitedLayoutOptions
                )
                consume(summary.totalLines)
                consume(summary.totalHeight)
                consume(summary.totalWidth)
            }
            let diagnostics = engine.diagnosticsSnapshot()
            let perItemMedian = batch.median / Double(max(listItems.count, 1))
            lines.append(
                "| \(policy.name) | \(format(batch.median)) | \(format(batch.p95)) | \(format(perItemMedian)) | \(percent(diagnostics.layoutPacketCache.hitRate)) | repeated chat/feed/list corpus with promoted display layout options |"
            )
        }

        print(lines.joined(separator: "\n"))
    }
}

struct ListSizingSummary {
    var totalLines: Int
    var totalHeight: Double
    var totalWidth: Double
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

private func sweepMeasurements(
    sampleCount: Int,
    widths _: [CGFloat],
    repetitionsPerSample: Int,
    block: () -> Void
) -> BenchmarkStats {
    batchMeasurements(
        sampleCount: sampleCount,
        repetitionsPerSample: repetitionsPerSample,
        block: block
    )
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

private func percent(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

private func envInt(_ name: String, default defaultValue: Int, minimum: Int) -> Int {
    guard let raw = ProcessInfo.processInfo.environment[name], let value = Int(raw) else {
        return max(defaultValue, minimum)
    }

    return max(value, minimum)
}

private func measureListSizing(
    engine: DefaultPreparedTextEngine,
    items: [BenchmarkFixture],
    env: MeasurementEnv,
    layoutOptions: PreparedTextLayoutOptions
) -> ListSizingSummary {
    var totalLines = 0
    var totalHeight = 0.0
    var totalWidth = 0.0

    for item in items {
        let prepared = engine.prepare(item.text, sourceID: PreparedTextSourceID(item.name), options: item.options)
        let packet = engine.layoutPacket(
            prepared,
            maxWidth: item.primaryWidth,
            lineHeight: item.lineHeight,
            env: env,
            options: layoutOptions
        )
        totalLines += packet.result.lineCount
        totalHeight += Double(packet.result.height)
        totalWidth += Double(packet.result.maxPaintWidth)
    }

    return ListSizingSummary(totalLines: totalLines, totalHeight: totalHeight, totalWidth: totalWidth)
}

private func makePolicies() -> [BenchmarkPolicy] {
    [
        BenchmarkPolicy(
            name: "exact",
            env: MeasurementEnv(
                scale: 2,
                contentSizeCategory: "large",
                localeIdentifier: Locale(identifier: "en_US").identifier,
                measurementOptions: PreparedTextMeasurementOptions(
                    widthNormalizationPolicy: .exactPixels,
                    pixelMeasurementPolicy: .exact
                )
            )
        ),
        BenchmarkPolicy(
            name: "bucketed-4pt",
            env: MeasurementEnv(
                scale: 2,
                contentSizeCategory: "large",
                localeIdentifier: Locale(identifier: "en_US").identifier,
                measurementOptions: PreparedTextMeasurementOptions(
                    widthNormalizationPolicy: .bucketed(points: 4),
                    pixelMeasurementPolicy: .exact
                )
            )
        ),
        BenchmarkPolicy(
            name: "pixel-aligned",
            env: MeasurementEnv(
                scale: 2,
                contentSizeCategory: "large",
                localeIdentifier: Locale(identifier: "en_US").identifier,
                measurementOptions: PreparedTextMeasurementOptions(
                    widthNormalizationPolicy: .exactPixels,
                    pixelMeasurementPolicy: .alignedToScale
                )
            )
        ),
    ]
}

private func jitteredWidths(from widths: [CGFloat]) -> [CGFloat] {
    widths.flatMap { width in
        [
            max(width - 1.1, 24),
            max(width - 0.35, 24),
            width,
            width + 0.4,
            width + 1.05,
        ]
    }
}

private func makeFixtures() -> [BenchmarkFixture] {
    let font = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
    let attributes: [NSAttributedString.Key: Any] = [kCTFontAttributeName as NSAttributedString.Key: font]

    func text(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: attributes)
    }

    func attachmentFixtureText() -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.bounds = CGRect(x: 0, y: -2, width: 22, height: 14)
        let attributed = NSMutableAttributedString(string: "Inline ", attributes: attributes)
        attributed.append(NSAttributedString(attachment: attachment))
        attributed.append(NSAttributedString(string: " attachment sizing should participate in prepared layout reuse.", attributes: attributes))
        return attributed
    }

    let englishBody = "Prepared layout reuse should keep self-sizing surfaces stable across repeated width negotiation."
    let korean = "준비된 텍스트 레이아웃은 반복되는 width negotiation 중에도 self-sizing 높이와 줄바꿈을 안정적으로 유지해야 한다."
    let emoji = "🙂🙂🙂 Emoji-heavy message cards should still reuse width-adjacent layouts instead of thrashing line breaks."
    let longToken = "https://prepared-layout-benchmarks.example.com/very/long/unbroken/token/with-query?cache=deterministic-and-reused"
    let longText = Array(
        repeating: "Long text sizing should amortize prepare work across width churn and keep list rows predictable.",
        count: 12
    ).joined(separator: " ")

    return [
        BenchmarkFixture(
            name: "latin-body",
            text: text(englishBody),
            primaryWidth: 240,
            sweepWidths: [180, 220, 240, 280, 320],
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "korean-cjk",
            text: text(korean),
            primaryWidth: 220,
            sweepWidths: [160, 200, 220, 260, 300],
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "emoji-heavy",
            text: text(emoji),
            primaryWidth: 240,
            sweepWidths: [180, 220, 240, 280, 320],
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "long-token",
            text: text(longToken),
            primaryWidth: 260,
            sweepWidths: [180, 220, 260, 300, 360],
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "attachment-inline",
            text: attachmentFixtureText(),
            primaryWidth: 240,
            sweepWidths: [180, 220, 240, 280, 320],
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
