import CoreText
import Foundation
import PretextCore

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
        let stage0Measurer = CachedFramesetterTextMeasurer()
        let engine = DefaultPreparedTextEngine()
        let measurementEnv = MeasurementEnv(scale: 2, contentSizeCategory: "large")

        let iterations = envInt("PRETEXT_BENCH_ITERATIONS", default: 24, minimum: 4)
        let sweepRepetitions = envInt("PRETEXT_BENCH_SWEEP_REPETITIONS", default: 12, minimum: 2)
        let nextLineRepetitions = envInt("PRETEXT_BENCH_NEXT_LINE_REPETITIONS", default: 24, minimum: 2)
        let listItemCount = envInt("PRETEXT_BENCH_LIST_ITEMS", default: 300, minimum: 24)
        let listBatchRepetitions = envInt("PRETEXT_BENCH_LIST_BATCH_REPETITIONS", default: 5, minimum: 1)

        let fixtures = makeFixtures()
        let listItems = makeListItems(count: listItemCount)

        var lines: [String] = []
        lines.append("# Benchmark Results")
        lines.append("")
        lines.append("- Date: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("- Runtime: host-side SwiftPM CLI on macOS (CoreText-only benchmark path)")
        lines.append("- Sample iterations: \(iterations)")
        lines.append("- Width sweep repetitions: \(sweepRepetitions)")
        lines.append("- NextLine repetitions: \(nextLineRepetitions)")
        lines.append("- List-style items: \(listItemCount)")
        lines.append("- List batch repetitions: \(listBatchRepetitions)")
        lines.append("")

        lines.append("## Stage 0 Measurement")
        lines.append("")
        lines.append("| Fixture | Cold Measure | Warm Measure Median | Warm Measure p95 | Width Sweep Median | Width Sweep p95 |")
        lines.append("| --- | ---: | ---: | ---: | ---: | ---: |")

        for fixture in fixtures {
            let sourceID = PreparedTextSourceID("bench-stage0-\(fixture.name)")

            let coldMeasure = timeMilliseconds {
                let size = stage0Measurer.measure(
                    fixture.text,
                    sourceID: sourceID,
                    width: fixture.primaryWidth,
                    env: measurementEnv
                )
                consume(size)
            }

            _ = stage0Measurer.measure(
                fixture.text,
                sourceID: sourceID,
                width: fixture.primaryWidth,
                env: measurementEnv
            )
            let warmMeasure = batchMeasurements(
                sampleCount: iterations,
                repetitionsPerSample: 8
            ) {
                let size = stage0Measurer.measure(
                    fixture.text,
                    sourceID: sourceID,
                    width: fixture.primaryWidth,
                    env: measurementEnv
                )
                consume(size)
            }

            let widthSweep = batchMeasurements(
                sampleCount: iterations,
                repetitionsPerSample: sweepRepetitions
            ) {
                for width in fixture.sweepWidths {
                    let size = stage0Measurer.measure(
                        fixture.text,
                        sourceID: sourceID,
                        width: width,
                        env: measurementEnv
                    )
                    consume(size)
                }
            }

            lines.append(
                "| \(fixture.name) | \(format(coldMeasure)) | \(format(warmMeasure.median)) | \(format(warmMeasure.p95)) | \(format(widthSweep.median)) | \(format(widthSweep.p95)) |"
            )
        }

        lines.append("")
        lines.append("## Stage 1 Prepared Layout")
        lines.append("")
        lines.append("| Fixture | Cold Prepare | Warm Prepare Median | Warm Prepare p95 | Hot Layout Median | Hot Layout p95 | NextLine Walk Median | NextLine Walk p95 |")
        lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")

        for fixture in fixtures {
            let sourceID = PreparedTextSourceID("bench-stage1-\(fixture.name)")

            engine.invalidateCaches()
            let coldPrepare = timeMilliseconds {
                let prepared = engine.prepare(fixture.text, sourceID: sourceID, options: fixture.options)
                consume(prepared.defaultLineHeight)
            }

            _ = engine.prepare(fixture.text, sourceID: sourceID, options: fixture.options)
            let warmPrepare = batchMeasurements(
                sampleCount: iterations,
                repetitionsPerSample: 8
            ) {
                let prepared = engine.prepare(fixture.text, sourceID: sourceID, options: fixture.options)
                consume(prepared.defaultLineHeight)
            }

            let prepared = engine.prepare(
                fixture.text,
                sourceID: PreparedTextSourceID("bench-stage1-layout-\(fixture.name)"),
                options: fixture.options
            )
            let hotLayout = batchMeasurements(
                sampleCount: iterations,
                repetitionsPerSample: 8
            ) {
                let result = engine.layout(prepared, maxWidth: fixture.primaryWidth, lineHeight: prepared.defaultLineHeight)
                consume(result.lineCount)
                consume(result.height)
                consume(result.maxPaintWidth)
            }

            let nextLineWalk = batchMeasurements(
                sampleCount: iterations,
                repetitionsPerSample: nextLineRepetitions
            ) {
                let walk = walkAllLines(engine: engine, prepared: prepared, width: fixture.primaryWidth)
                consume(walk.lineCount)
                consume(walk.finalWidth)
            }

            lines.append(
                "| \(fixture.name) | \(format(coldPrepare)) | \(format(warmPrepare.median)) | \(format(warmPrepare.p95)) | \(format(hotLayout.median)) | \(format(hotLayout.p95)) | \(format(nextLineWalk.median)) | \(format(nextLineWalk.p95)) |"
            )
        }

        lines.append("")
        lines.append("## Long Text And List Sizing")
        lines.append("")
        lines.append("| Scenario | Batch Median | Batch p95 | Per-Item Median | Notes |")
        lines.append("| --- | ---: | ---: | ---: | --- |")

        let longTextFixture = fixtures.first { $0.name == "long-text" } ?? fixtures[0]
        let longTextBatch = batchMeasurements(
            sampleCount: iterations,
            repetitionsPerSample: 4
        ) {
            let prepared = engine.prepare(
                longTextFixture.text,
                sourceID: PreparedTextSourceID("bench-long-text"),
                options: longTextFixture.options
            )
            let result = engine.layout(prepared, maxWidth: longTextFixture.primaryWidth, lineHeight: longTextFixture.lineHeight)
            consume(result.lineCount)
            consume(result.height)
            consume(result.maxPaintWidth)
        }
        lines.append(
            "| long-text-layout | \(format(longTextBatch.median)) | \(format(longTextBatch.p95)) | \(format(longTextBatch.median)) | \(longTextFixture.name) at width \(Int(longTextFixture.primaryWidth)) |"
        )

        let listBatch = batchMeasurements(
            sampleCount: iterations,
            repetitionsPerSample: listBatchRepetitions
        ) {
            let summary = measureListSizing(engine: engine, items: listItems)
            consume(summary.totalLines)
            consume(summary.totalHeight)
            consume(summary.totalWidth)
        }
        let perItemMedian = listBatch.median / Double(max(listItems.count, 1))
        lines.append(
            "| list-style-sizing-\(listItems.count) | \(format(listBatch.median)) | \(format(listBatch.p95)) | \(format(perItemMedian)) | repeated mixed feed/list/chat bodies |"
        )

        let stats = stage0Measurer.stats
        lines.append("")
        lines.append("## Cache Summary")
        lines.append("")
        lines.append("- Stage 0 cache hits: \(stats.hitCount)")
        lines.append("- Stage 0 cache misses: \(stats.missCount)")
        lines.append("- Stage 0 hit rate: \(format(stats.hitRate * 100))%")

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

private func envInt(_ name: String, default defaultValue: Int, minimum: Int) -> Int {
    guard let raw = ProcessInfo.processInfo.environment[name], let value = Int(raw) else {
        return max(defaultValue, minimum)
    }

    return max(value, minimum)
}

private func walkAllLines(
    engine: PreparedTextEngine,
    prepared: PreparedText,
    width: CGFloat
) -> (lineCount: Int, finalWidth: CGFloat) {
    var cursor = LayoutCursor()
    var lineCount = 0
    var finalWidth: CGFloat = 0

    while let line = engine.nextLine(prepared, cursor: cursor, maxWidth: width) {
        lineCount += 1
        finalWidth = max(finalWidth, line.width)
        cursor = line.end
        consume(line.paintWidth)
    }

    return (lineCount, finalWidth)
}

private func measureListSizing(
    engine: PreparedTextEngine,
    items: [BenchmarkFixture]
) -> ListSizingSummary {
    var totalLines = 0
    var totalHeight = 0.0
    var totalWidth = 0.0

    for item in items {
        let prepared = engine.prepare(item.text, sourceID: PreparedTextSourceID(item.name), options: item.options)
        let result = engine.layout(prepared, maxWidth: item.primaryWidth, lineHeight: item.lineHeight)
        totalLines += result.lineCount
        totalHeight += Double(result.height)
        totalWidth += Double(result.maxPaintWidth)
    }

    return ListSizingSummary(totalLines: totalLines, totalHeight: totalHeight, totalWidth: totalWidth)
}

private func makeFixtures() -> [BenchmarkFixture] {
    let font = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
    let attributes: [NSAttributedString.Key: Any] = [kCTFontAttributeName as NSAttributedString.Key: font]

    func text(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: attributes)
    }

    let shortBody = "Prepared text layout should front-load expensive measurement work and keep repeated width churn cheap."
    let mixedBidi = "Feed cards with English, العربية, and emoji 🙂 should stay stable across widths."
    let cjk = "文節ごとの折り返しと日本語の段落は、幅変更のたびに無駄なく再計算したい。"
    let prewrap = "Tabs\tstay visible\nand soft hy\u{00AD}phens appear only when selected."
    let longText = Array(repeating: "Long text sizing should amortize prepare work across width churn and keep list rows predictable.", count: 12)
        .joined(separator: " ")

    return [
        BenchmarkFixture(
            name: "body-english",
            text: text(shortBody),
            primaryWidth: 240,
            sweepWidths: [160, 200, 240, 280, 320, 400],
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "mixed-bidi",
            text: text(mixedBidi),
            primaryWidth: 260,
            sweepWidths: [180, 220, 260, 320, 380],
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "cjk",
            text: text(cjk),
            primaryWidth: 220,
            sweepWidths: [140, 180, 220, 260, 320],
            lineHeight: 20
        ),
        BenchmarkFixture(
            name: "prewrap",
            text: text(prewrap),
            primaryWidth: 220,
            sweepWidths: [160, 200, 220, 260, 320],
            options: PreparedTextOptions(whiteSpaceMode: .preWrap),
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
