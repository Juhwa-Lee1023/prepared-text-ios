import CoreGraphics
import CoreText
import Foundation
import PretextCore

public struct PreparedTextObstacleCircle: Hashable {
    public var center: CGPoint
    public var radius: CGFloat

    public init(center: CGPoint, radius: CGFloat) {
        self.center = center
        self.radius = radius
    }
}

public enum PreparedObstacleShape: Hashable {
    case circle(PreparedTextObstacleCircle)
}

public struct PreparedObstacle: Hashable {
    public var shape: PreparedObstacleShape

    public init(shape: PreparedObstacleShape) {
        self.shape = shape
    }

    public init(circle: PreparedTextObstacleCircle) {
        self.shape = .circle(circle)
    }

    public var circle: PreparedTextObstacleCircle? {
        switch shape {
        case let .circle(circle):
            return circle
        }
    }
}

public struct PreparedTextObstacleLayoutFragment {
    public var rowIndex: Int
    public var rowY: CGFloat
    public var originX: CGFloat
    public var spanWidth: CGFloat
    public var attributedText: NSAttributedString
    public var ctLine: CTLine
    public var ascent: CGFloat
    public var descent: CGFloat
    public var leading: CGFloat
    public var plainText: String
    public var sourceUTF16Range: NSRange

    public init(
        rowIndex: Int,
        rowY: CGFloat,
        originX: CGFloat,
        spanWidth: CGFloat,
        attributedText: NSAttributedString,
        ctLine: CTLine,
        ascent: CGFloat,
        descent: CGFloat,
        leading: CGFloat,
        plainText: String,
        sourceUTF16Range: NSRange
    ) {
        self.rowIndex = rowIndex
        self.rowY = rowY
        self.originX = originX
        self.spanWidth = spanWidth
        self.attributedText = attributedText
        self.ctLine = ctLine
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.plainText = plainText
        self.sourceUTF16Range = sourceUTF16Range
    }
}

public struct PreparedTextObstacleLayoutSnapshot: Hashable, Sendable {
    public var obstacleCount: Int
    public var rowCount: Int
    public var fragmentCount: Int
    public var splitRowCount: Int
    public var renderedStrings: [String]

    public init(
        obstacleCount: Int,
        rowCount: Int,
        fragmentCount: Int,
        splitRowCount: Int,
        renderedStrings: [String]
    ) {
        self.obstacleCount = obstacleCount
        self.rowCount = rowCount
        self.fragmentCount = fragmentCount
        self.splitRowCount = splitRowCount
        self.renderedStrings = renderedStrings
    }
}

public struct PreparedTextObstacleLayoutResult {
    public var textRect: CGRect
    public var rowHeight: CGFloat
    public var obstacles: [PreparedTextObstacleCircle]
    public var preparedObstacles: [PreparedObstacle]
    public var fragments: [PreparedTextObstacleLayoutFragment]
    public var splitRowIndices: Set<Int>
    public var rowCount: Int

    public init(
        textRect: CGRect,
        rowHeight: CGFloat,
        obstacles: [PreparedTextObstacleCircle],
        preparedObstacles: [PreparedObstacle]? = nil,
        fragments: [PreparedTextObstacleLayoutFragment],
        splitRowIndices: Set<Int>,
        rowCount: Int
    ) {
        self.textRect = textRect
        self.rowHeight = rowHeight
        self.obstacles = obstacles
        self.preparedObstacles = preparedObstacles ?? obstacles.map(PreparedObstacle.init(circle:))
        self.fragments = fragments
        self.splitRowIndices = splitRowIndices
        self.rowCount = rowCount
    }

    public var snapshot: PreparedTextObstacleLayoutSnapshot {
        PreparedTextObstacleLayoutSnapshot(
            obstacleCount: preparedObstacles.count,
            rowCount: rowCount,
            fragmentCount: fragments.count,
            splitRowCount: splitRowIndices.count,
            renderedStrings: fragments.map(\.plainText)
        )
    }

    public var visibleSourceUTF16Ranges: [NSRange] {
        fragments.map(\.sourceUTF16Range)
    }

    public func sourceCoordinateMap(in prepared: PreparedText) -> PreparedTextSourceCoordinateMap {
        PreparedTextSourceCoordinateMap(
            mappingMode: prepared.sourceCoordinateMappingMode,
            lines: fragments.enumerated().map { index, fragment in
                let start = prepared.cursor(forUTF16Offset: fragment.sourceUTF16Range.location)
                let end = prepared.cursor(forUTF16Offset: NSMaxRange(fragment.sourceUTF16Range))
                return PreparedTextSourceCoordinateLine(
                    lineIndex: index,
                    fragment: LineFragment(
                        start: start,
                        end: end,
                        paintEnd: end,
                        fitWidth: fragment.spanWidth,
                        paintWidth: fragment.spanWidth,
                        trailingWhitespaceWidth: 0,
                        ascent: fragment.ascent,
                        descent: fragment.descent,
                        leading: fragment.leading,
                        blockAdvance: rowHeight
                    ),
                    displayUTF16Length: fragment.attributedText.length,
                    consumedSourceUTF16Range: fragment.sourceUTF16Range,
                    sourceSpans: [
                        PreparedTextSourceCoordinateSpan(
                            displayUTF16Range: NSRange(location: 0, length: fragment.attributedText.length),
                            sourceUTF16Range: fragment.sourceUTF16Range
                        ),
                    ],
                    isTruncated: false
                )
            }
        )
    }

    public func visibleTokens(in prepared: PreparedText) -> [PreparedToken] {
        sourceCoordinateMap(in: prepared).visibleTokens(in: prepared)
    }

    public func visibleAnnotations(in prepared: PreparedText) -> [PreparedAnnotation] {
        sourceCoordinateMap(in: prepared).visibleAnnotations(in: prepared)
    }

    public func visibleAttachmentSpans(in prepared: PreparedText) -> [PreparedAttachmentSpan] {
        sourceCoordinateMap(in: prepared).visibleAttachmentSpans(in: prepared)
    }
}

@MainActor
public final class PreparedTextObstacleLayouter {
    public var textSystem: PreparedTextSystem

    public init(textSystem: PreparedTextSystem = .shared) {
        self.textSystem = textSystem
    }

    public func layout(
        prepared: PreparedText,
        in textRect: CGRect,
        obstacles: [PreparedTextObstacleCircle],
        lineHeight: CGFloat? = nil,
        obstaclePadding: CGFloat = 12,
        minimumSpanWidth: CGFloat = 30
    ) -> PreparedTextObstacleLayoutResult {
        layout(
            prepared: prepared,
            in: textRect,
            obstacles: obstacles.map(PreparedObstacle.init(circle:)),
            lineHeight: lineHeight,
            obstaclePadding: obstaclePadding,
            minimumSpanWidth: minimumSpanWidth
        )
    }

    public func layout(
        prepared: PreparedText,
        in textRect: CGRect,
        obstacles: [PreparedObstacle],
        lineHeight: CGFloat? = nil,
        obstaclePadding: CGFloat = 12,
        minimumSpanWidth: CGFloat = 30
    ) -> PreparedTextObstacleLayoutResult {
        let circles = obstacles.compactMap(\.circle)
        guard !textRect.isNull, textRect.width > 0 else {
            return PreparedTextObstacleLayoutResult(
                textRect: textRect,
                rowHeight: 0,
                obstacles: circles,
                preparedObstacles: obstacles,
                fragments: [],
                splitRowIndices: [],
                rowCount: 0
            )
        }

        let rowHeight = max(lineHeight ?? prepared.defaultLineHeight, 1)
        var cursor = LayoutCursor()
        var rowY = textRect.minY
        var rowIndex = 0
        var fragments: [PreparedTextObstacleLayoutFragment] = []
        var splitRowIndices = Set<Int>()

        layoutLoop: while rowY < textRect.maxY - 0.5 {
            let bandRect = CGRect(x: textRect.minX, y: rowY, width: textRect.width, height: rowHeight)
            let spans = availableSpans(
                in: bandRect,
                textRect: textRect,
                obstacles: circles,
                obstaclePadding: obstaclePadding,
                minimumSpanWidth: minimumSpanWidth
            )
            if spans.count > 1 {
                splitRowIndices.insert(rowIndex)
            }

            if spans.isEmpty {
                rowY += rowHeight
                rowIndex += 1
                continue
            }

            var rowProgressed = false
            var exhaustedText = false

            for span in spans {
                guard let line = textSystem.engine.nextLine(prepared, cursor: cursor, maxWidth: span.width) else {
                    exhaustedText = true
                    break
                }

                if line.end == cursor, line.paintEnd == line.start {
                    continue
                }

                let attributedLine = textSystem.engine.attributedLine(prepared, line: line)
                let ctLine = CTLineCreateWithAttributedString(attributedLine as CFAttributedString)
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                _ = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)

                fragments.append(
                    PreparedTextObstacleLayoutFragment(
                        rowIndex: rowIndex,
                        rowY: rowY,
                        originX: span.minX,
                        spanWidth: span.width,
                        attributedText: attributedLine,
                        ctLine: ctLine,
                        ascent: ascent,
                        descent: descent,
                        leading: leading,
                        plainText: line.text ?? attributedLine.string,
                        sourceUTF16Range: NSRange(
                            location: prepared.utf16Offset(for: line.start),
                            length: max(prepared.utf16Offset(for: line.end) - prepared.utf16Offset(for: line.start), 0)
                        )
                    )
                )
                let consumedHardBreak = lineConsumesHardBreak(line, in: prepared)
                cursor = line.end
                rowProgressed = true
                if consumedHardBreak {
                    break
                }
            }

            if !rowProgressed {
                break
            }

            rowY += rowHeight
            rowIndex += 1
            if exhaustedText {
                break layoutLoop
            }
        }

        return PreparedTextObstacleLayoutResult(
            textRect: textRect,
            rowHeight: rowHeight,
            obstacles: circles,
            preparedObstacles: obstacles,
            fragments: fragments,
            splitRowIndices: splitRowIndices,
            rowCount: rowIndex
        )
    }

    private func lineConsumesHardBreak(_ line: LineResult, in prepared: PreparedText) -> Bool {
        guard line.paintEnd < line.end else {
            return false
        }

        let trailingText = textSystem.attributedText(
            prepared,
            from: line.paintEnd,
            to: line.end,
            flatteningHardBreaks: false
        )
        return trailingText.string.rangeOfCharacter(from: .newlines) != nil
    }

    private func availableSpans(
        in bandRect: CGRect,
        textRect: CGRect,
        obstacles: [PreparedTextObstacleCircle],
        obstaclePadding: CGFloat,
        minimumSpanWidth: CGFloat
    ) -> [PreparedTextObstacleHorizontalSpan] {
        guard bandRect.width > 0 else {
            return []
        }

        let intervals = mergedExclusionIntervals(
            in: bandRect,
            textRect: textRect,
            obstacles: obstacles,
            obstaclePadding: obstaclePadding
        )
        if intervals.isEmpty {
            return [PreparedTextObstacleHorizontalSpan(minX: textRect.minX, maxX: textRect.maxX)]
        }

        var spans: [PreparedTextObstacleHorizontalSpan] = []
        var currentMinX = textRect.minX

        for interval in intervals {
            if interval.minX - currentMinX >= minimumSpanWidth {
                spans.append(PreparedTextObstacleHorizontalSpan(minX: currentMinX, maxX: interval.minX))
            }
            currentMinX = max(currentMinX, interval.maxX)
        }

        if textRect.maxX - currentMinX >= minimumSpanWidth {
            spans.append(PreparedTextObstacleHorizontalSpan(minX: currentMinX, maxX: textRect.maxX))
        }

        return spans
    }

    private func mergedExclusionIntervals(
        in bandRect: CGRect,
        textRect: CGRect,
        obstacles: [PreparedTextObstacleCircle],
        obstaclePadding: CGFloat
    ) -> [PreparedTextObstacleHorizontalSpan] {
        let midY = bandRect.midY
        var intervals: [PreparedTextObstacleHorizontalSpan] = []

        for obstacle in obstacles {
            let layoutRadius = obstacle.radius + obstaclePadding
            let distanceY = abs(midY - obstacle.center.y)
            guard distanceY < layoutRadius else {
                continue
            }

            let deltaX = sqrt(max((layoutRadius * layoutRadius) - (distanceY * distanceY), 0))
            let minX = max(textRect.minX, obstacle.center.x - deltaX)
            let maxX = min(textRect.maxX, obstacle.center.x + deltaX)
            guard maxX - minX > 0 else {
                continue
            }
            intervals.append(PreparedTextObstacleHorizontalSpan(minX: minX, maxX: maxX))
        }

        let sorted = intervals.sorted { lhs, rhs in
            if lhs.minX == rhs.minX {
                return lhs.maxX < rhs.maxX
            }
            return lhs.minX < rhs.minX
        }

        var merged: [PreparedTextObstacleHorizontalSpan] = []
        for interval in sorted {
            guard var last = merged.popLast() else {
                merged.append(interval)
                continue
            }

            if interval.minX <= last.maxX + 4 {
                last.maxX = max(last.maxX, interval.maxX)
                merged.append(last)
            } else {
                merged.append(last)
                merged.append(interval)
            }
        }

        return merged
    }
}

private struct PreparedTextObstacleHorizontalSpan: Hashable {
    var minX: CGFloat
    var maxX: CGFloat

    var width: CGFloat {
        max(maxX - minX, 0)
    }
}
