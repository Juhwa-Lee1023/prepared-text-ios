import CoreGraphics
import CoreText
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum PreparedTextLineBreakMode: String, Hashable, Sendable {
    case wordWrap
    case characterWrap
    case clip
    case truncateHead
    case truncateMiddle
    case truncateTail
}

/// Controls which core line-breaking path the prepared layout engine uses.
///
/// This remains intentionally narrow. It does not promise browser-grade line breaking;
/// it only selects between the engine's prepared walker and Core Text's native typesetter
/// where that materially affects read-only prepared layout reuse.
public enum PreparedTextLineBreakStrategy: String, Hashable, Sendable {
    /// Use the engine's built-in heuristic to choose between conservative prepared breaking
    /// and the native Core Text typesetter for scripts that benefit from it.
    case automatic

    /// Stay on the prepared walker that favors conservative UIKit-like break decisions.
    case uikitConservative

    /// Prefer the prepared walker for URL/social-token-heavy copy where delimiter-aware
    /// breaking is often more important than native typesetter shaping.
    case urlFriendly

    /// Prefer the native typesetter for CJK-heavy or mixed-script copy when available.
    case cjkImproved

    /// Always prefer the native typesetter when a coordinate-preserving native source exists.
    case nativeTypesetterPreferred
}

public enum PreparedTextHorizontalAlignment: String, Hashable, Sendable {
    case natural
    case left
    case leading
    case center
    case trailing
    case right
}

public enum PreparedTextLayoutDirection: String, Hashable, Sendable {
    case natural
    case leftToRight
    case rightToLeft
}

public struct PreparedTextLayoutOptions: Hashable, Sendable {
    public var maximumNumberOfLines: Int
    public var lineBreakMode: PreparedTextLineBreakMode
    public var lineBreakStrategy: PreparedTextLineBreakStrategy
    public var alignment: PreparedTextHorizontalAlignment
    public var layoutDirection: PreparedTextLayoutDirection

    public init(
        maximumNumberOfLines: Int = 0,
        lineBreakMode: PreparedTextLineBreakMode = .truncateTail,
        lineBreakStrategy: PreparedTextLineBreakStrategy = .automatic,
        alignment: PreparedTextHorizontalAlignment = .natural,
        layoutDirection: PreparedTextLayoutDirection = .natural
    ) {
        self.maximumNumberOfLines = max(maximumNumberOfLines, 0)
        self.lineBreakMode = lineBreakMode
        self.lineBreakStrategy = lineBreakStrategy
        self.alignment = alignment
        self.layoutDirection = layoutDirection
    }

    public static let `default` = PreparedTextLayoutOptions()
}

public enum PreparedTextSourceCoordinateMappingMode: String, Hashable, Sendable {
    case exact
    case bestEffort
}

public struct PreparedTextDisplayedSpan: Hashable, Sendable {
    public var lineIndex: Int
    public var displayUTF16Range: NSRange
    public var sourceUTF16Range: NSRange?
    public var displayRect: CGRect?
    public var isTruncatedLine: Bool
    public var isExact: Bool

    public init(
        lineIndex: Int,
        displayUTF16Range: NSRange,
        sourceUTF16Range: NSRange?,
        displayRect: CGRect? = nil,
        isTruncatedLine: Bool,
        isExact: Bool = false
    ) {
        self.lineIndex = lineIndex
        self.displayUTF16Range = displayUTF16Range
        self.sourceUTF16Range = sourceUTF16Range
        self.displayRect = displayRect
        self.isTruncatedLine = isTruncatedLine
        self.isExact = isExact
    }
}

public struct PreparedTextDisplayedRect: Hashable, Sendable {
    public var lineIndex: Int
    public var rect: CGRect
    public var displayUTF16Range: NSRange
    public var sourceUTF16Range: NSRange?
    public var isTruncatedLine: Bool
    public var isExact: Bool

    public init(
        lineIndex: Int,
        rect: CGRect,
        displayUTF16Range: NSRange,
        sourceUTF16Range: NSRange?,
        isTruncatedLine: Bool,
        isExact: Bool
    ) {
        self.lineIndex = lineIndex
        self.rect = rect
        self.displayUTF16Range = displayUTF16Range
        self.sourceUTF16Range = sourceUTF16Range
        self.isTruncatedLine = isTruncatedLine
        self.isExact = isExact
    }
}

public struct PreparedTextSourceCoordinateSpan: Hashable, Sendable {
    public var displayUTF16Range: NSRange
    public var sourceUTF16Range: NSRange?
    public var displayRect: CGRect?

    public init(
        displayUTF16Range: NSRange,
        sourceUTF16Range: NSRange?,
        displayRect: CGRect? = nil
    ) {
        self.displayUTF16Range = displayUTF16Range
        self.sourceUTF16Range = sourceUTF16Range
        self.displayRect = displayRect
    }
}

public struct PreparedTextSourceCoordinateLine: Hashable, Sendable {
    public var lineIndex: Int
    public var fragment: LineFragment
    public var displayUTF16Length: Int
    public var consumedSourceUTF16Range: NSRange
    public var sourceSpans: [PreparedTextSourceCoordinateSpan]
    public var isTruncated: Bool
    public var displayFrame: CGRect

    public init(
        lineIndex: Int,
        fragment: LineFragment,
        displayUTF16Length: Int,
        consumedSourceUTF16Range: NSRange,
        sourceSpans: [PreparedTextSourceCoordinateSpan],
        isTruncated: Bool,
        displayFrame: CGRect = .zero
    ) {
        self.lineIndex = lineIndex
        self.fragment = fragment
        self.displayUTF16Length = displayUTF16Length
        self.consumedSourceUTF16Range = consumedSourceUTF16Range
        self.sourceSpans = sourceSpans
        self.isTruncated = isTruncated
        self.displayFrame = displayFrame
    }

    public var visibleSourceUTF16Ranges: [NSRange] {
        sourceSpans.compactMap(\.sourceUTF16Range)
    }

    public var displayUTF16Range: NSRange {
        NSRange(location: 0, length: displayUTF16Length)
    }
}

public struct PreparedTextSourceCoordinateMap: Hashable, Sendable {
    public var mappingMode: PreparedTextSourceCoordinateMappingMode
    public var lines: [PreparedTextSourceCoordinateLine]

    public init(
        mappingMode: PreparedTextSourceCoordinateMappingMode = .exact,
        lines: [PreparedTextSourceCoordinateLine]
    ) {
        self.mappingMode = mappingMode
        self.lines = lines
    }

    public var visibleSourceUTF16Ranges: [NSRange] {
        preparedMergedRanges(lines.flatMap(\.visibleSourceUTF16Ranges))
    }

    public var isExact: Bool {
        mappingMode == .exact
    }

    public func line(at index: Int) -> PreparedTextSourceCoordinateLine? {
        lines.first { $0.lineIndex == index }
    }

    public func displayedLineFrame(at index: Int) -> CGRect? {
        line(at: index)?.displayFrame
    }

    public func sourceUTF16Ranges(onDisplayedLine lineIndex: Int) -> [NSRange] {
        line(at: lineIndex)?.visibleSourceUTF16Ranges ?? []
    }

    public func displayedSpans(forSourceUTF16Range sourceUTF16Range: NSRange) -> [PreparedTextDisplayedSpan] {
        guard sourceUTF16Range.length > 0 else {
            return []
        }

        var matches: [PreparedTextDisplayedSpan] = []
        for line in lines {
            for span in line.sourceSpans {
                guard let sourceRange = span.sourceUTF16Range else {
                    continue
                }
                let intersection = NSIntersectionRange(sourceRange, sourceUTF16Range)
                guard intersection.length > 0 else {
                    continue
                }

                let displayRange: NSRange
                let canResolveExactDisplayRange = mappingMode == .exact &&
                    sourceRange.length == span.displayUTF16Range.length
                let isExact = canResolveExactDisplayRange && NSEqualRanges(intersection, sourceRange)
                if canResolveExactDisplayRange {
                    let delta = intersection.location - sourceRange.location
                    displayRange = NSRange(
                        location: span.displayUTF16Range.location + delta,
                        length: intersection.length
                    )
                } else {
                    displayRange = span.displayUTF16Range
                }

                matches.append(
                    PreparedTextDisplayedSpan(
                        lineIndex: line.lineIndex,
                        displayUTF16Range: displayRange,
                        sourceUTF16Range: intersection,
                        displayRect: span.displayRect,
                        isTruncatedLine: line.isTruncated,
                        isExact: isExact
                    )
                )
            }
        }

        return matches
    }

    public func displayedRects(forSourceUTF16Range sourceUTF16Range: NSRange) -> [PreparedTextDisplayedRect] {
        displayedRects(forSourceUTF16Range: sourceUTF16Range, onLine: nil)
    }

    public func displayedRects(
        forSourceUTF16Range sourceUTF16Range: NSRange,
        onLine lineIndex: Int?
    ) -> [PreparedTextDisplayedRect] {
        guard sourceUTF16Range.length > 0 else {
            return []
        }

        return displayedSpans(forSourceUTF16Range: sourceUTF16Range).compactMap { span in
            if let lineIndex, span.lineIndex != lineIndex {
                return nil
            }
            guard let rect = span.displayRect, rect.isNull == false, rect.isEmpty == false else {
                return nil
            }
            return PreparedTextDisplayedRect(
                lineIndex: span.lineIndex,
                rect: rect,
                displayUTF16Range: span.displayUTF16Range,
                sourceUTF16Range: span.sourceUTF16Range,
                isTruncatedLine: span.isTruncatedLine,
                isExact: span.isExact
            )
        }
    }

    public func sourceUTF16Ranges(
        forDisplayedUTF16Range displayUTF16Range: NSRange,
        onLine lineIndex: Int
    ) -> [NSRange] {
        guard displayUTF16Range.length > 0, let line = line(at: lineIndex) else {
            return []
        }

        var matches: [NSRange] = []
        for span in line.sourceSpans {
            guard let sourceRange = span.sourceUTF16Range else {
                continue
            }
            let intersection = NSIntersectionRange(span.displayUTF16Range, displayUTF16Range)
            guard intersection.length > 0 else {
                continue
            }

            if mappingMode == .exact, sourceRange.length == span.displayUTF16Range.length {
                let delta = intersection.location - span.displayUTF16Range.location
                matches.append(NSRange(location: sourceRange.location + delta, length: intersection.length))
            } else {
                matches.append(sourceRange)
            }
        }

        return preparedMergedRanges(matches)
    }

    public func visibleSourceUTF16Ranges(intersecting sourceUTF16Range: NSRange) -> [NSRange] {
        guard sourceUTF16Range.length > 0 else {
            return []
        }

        return preparedMergedRanges(
            visibleSourceUTF16Ranges.compactMap { range in
                let intersection = NSIntersectionRange(range, sourceUTF16Range)
                return intersection.length > 0 ? intersection : nil
            }
        )
    }

    public func isSourceRangeVisible(_ sourceUTF16Range: NSRange) -> Bool {
        visibleSourceUTF16Ranges(intersecting: sourceUTF16Range).isEmpty == false
    }

    public func visibleTokens(in prepared: PreparedText) -> [PreparedToken] {
        prepared.tokens.filter { isSourceRangeVisible($0.sourceUTF16Range) }
    }

    public func visibleAnnotations(in prepared: PreparedText) -> [PreparedAnnotation] {
        prepared.annotations.filter { isSourceRangeVisible($0.sourceUTF16Range) }
    }

    public func visibleAttachmentSpans(in prepared: PreparedText) -> [PreparedAttachmentSpan] {
        prepared.attachmentSpans.filter { isSourceRangeVisible($0.sourceUTF16Range) }
    }

    public func displayedRects(for token: PreparedToken) -> [PreparedTextDisplayedRect] {
        displayedRects(forSourceUTF16Range: token.sourceUTF16Range)
    }

    public func displayedRects(for annotation: PreparedAnnotation) -> [PreparedTextDisplayedRect] {
        displayedRects(forSourceUTF16Range: annotation.sourceUTF16Range)
    }

    public func displayedRects(for attachmentSpan: PreparedAttachmentSpan) -> [PreparedTextDisplayedRect] {
        displayedRects(forSourceUTF16Range: attachmentSpan.sourceUTF16Range)
    }
}

public struct PreparedTextDisplayLine {
    public var fragment: LineFragment
    public var attributedText: NSAttributedString
    public var ctLine: CTLine
    public var lineWidth: CGFloat
    public var originX: CGFloat
    public var isTruncated: Bool
    public var consumedSourceUTF16Range: NSRange
    public var sourceSpans: [PreparedTextSourceCoordinateSpan]

    public init(
        fragment: LineFragment,
        attributedText: NSAttributedString,
        ctLine: CTLine,
        lineWidth: CGFloat,
        originX: CGFloat,
        isTruncated: Bool,
        consumedSourceUTF16Range: NSRange,
        sourceSpans: [PreparedTextSourceCoordinateSpan]
    ) {
        self.fragment = fragment
        self.attributedText = attributedText
        self.ctLine = ctLine
        self.lineWidth = lineWidth
        self.originX = originX
        self.isTruncated = isTruncated
        self.consumedSourceUTF16Range = consumedSourceUTF16Range
        self.sourceSpans = sourceSpans
    }

    public func frame(originY: CGFloat) -> CGRect {
        let typographicTop = originY + fragment.paragraphSpacingBefore
        let typographicHeight = max(fragment.ascent + fragment.descent + fragment.leading, 1)
        return CGRect(x: originX, y: typographicTop, width: lineWidth, height: typographicHeight)
    }

    public var coordinateLine: PreparedTextSourceCoordinateLine {
        PreparedTextSourceCoordinateLine(
            lineIndex: 0,
            fragment: fragment,
            displayUTF16Length: attributedText.length,
            consumedSourceUTF16Range: consumedSourceUTF16Range,
            sourceSpans: sourceSpans,
            isTruncated: isTruncated
        )
    }
}

public struct PreparedTextDisplayPacket {
    public var result: LayoutResult
    public var lines: [PreparedTextDisplayLine]
    public var sourceCoordinateMappingMode: PreparedTextSourceCoordinateMappingMode

    public init(
        result: LayoutResult,
        lines: [PreparedTextDisplayLine],
        sourceCoordinateMappingMode: PreparedTextSourceCoordinateMappingMode = .exact
    ) {
        self.result = result
        self.lines = lines
        self.sourceCoordinateMappingMode = sourceCoordinateMappingMode
    }

    public var sourceCoordinateMap: PreparedTextSourceCoordinateMap {
        var originY: CGFloat = 0
        return PreparedTextSourceCoordinateMap(
            mappingMode: sourceCoordinateMappingMode,
            lines: lines.enumerated().map { index, line in
                defer { originY += line.fragment.blockAdvance }
                let lineFrame = preparedCoordinateDisplayFrame(
                    originX: line.originX,
                    originY: originY,
                    lineWidth: line.lineWidth,
                    fragment: line.fragment
                )
                return PreparedTextSourceCoordinateLine(
                    lineIndex: index,
                    fragment: line.fragment,
                    displayUTF16Length: line.attributedText.length,
                    consumedSourceUTF16Range: line.consumedSourceUTF16Range,
                    sourceSpans: preparedCoordinateSpans(
                        from: line.sourceSpans,
                        attributedText: line.attributedText,
                        ctLine: line.ctLine,
                        originX: line.originX,
                        originY: originY,
                        lineWidth: line.lineWidth,
                        fragment: line.fragment
                    ),
                    isTruncated: line.isTruncated,
                    displayFrame: lineFrame
                )
            }
        )
    }
}

public extension PreparedText {
    func utf16Offset(for cursor: LayoutCursor) -> Int {
        var offset = 0
        let core = storage.core
        for index in 0..<min(cursor.segmentIndex, core.segments.count) {
            offset += core.segments[index].string.utf16.count
        }

        guard core.segments.indices.contains(cursor.segmentIndex) else {
            return offset
        }

        let segment = core.segments[cursor.segmentIndex]
        return offset + segment.graphemeUTF16Offsets[min(cursor.graphemeIndex, segment.graphemeUTF16Offsets.count - 1)]
    }

    func cursor(forUTF16Offset utf16Offset: Int) -> LayoutCursor {
        var remaining = max(utf16Offset, 0)

        for (segmentIndex, segment) in storage.core.segments.enumerated() {
            let segmentLength = segment.string.utf16.count
            if remaining > segmentLength {
                remaining -= segmentLength
                continue
            }

            if remaining == segmentLength {
                return LayoutCursor(segmentIndex: segmentIndex + 1, graphemeIndex: 0)
            }

            for graphemeIndex in 0..<segment.graphemeUTF16Offsets.count where segment.graphemeUTF16Offsets[graphemeIndex] >= remaining {
                return LayoutCursor(segmentIndex: segmentIndex, graphemeIndex: graphemeIndex)
            }

            return LayoutCursor(segmentIndex: segmentIndex + 1, graphemeIndex: 0)
        }

        return LayoutCursor(segmentIndex: storage.core.segments.count, graphemeIndex: 0)
    }
}

public extension PreparedToken {
    func displayedSpans(in map: PreparedTextSourceCoordinateMap) -> [PreparedTextDisplayedSpan] {
        map.displayedSpans(forSourceUTF16Range: sourceUTF16Range)
    }

    func displayedRects(in map: PreparedTextSourceCoordinateMap) -> [PreparedTextDisplayedRect] {
        map.displayedRects(for: self)
    }

    func isVisible(in map: PreparedTextSourceCoordinateMap) -> Bool {
        map.isSourceRangeVisible(sourceUTF16Range)
    }
}

public extension PreparedAnnotation {
    func displayedSpans(in map: PreparedTextSourceCoordinateMap) -> [PreparedTextDisplayedSpan] {
        map.displayedSpans(forSourceUTF16Range: sourceUTF16Range)
    }

    func displayedRects(in map: PreparedTextSourceCoordinateMap) -> [PreparedTextDisplayedRect] {
        map.displayedRects(for: self)
    }

    func isVisible(in map: PreparedTextSourceCoordinateMap) -> Bool {
        map.isSourceRangeVisible(sourceUTF16Range)
    }
}

public extension PreparedAttachmentSpan {
    func displayedSpans(in map: PreparedTextSourceCoordinateMap) -> [PreparedTextDisplayedSpan] {
        map.displayedSpans(forSourceUTF16Range: sourceUTF16Range)
    }

    func displayedRects(in map: PreparedTextSourceCoordinateMap) -> [PreparedTextDisplayedRect] {
        map.displayedRects(for: self)
    }

    func isVisible(in map: PreparedTextSourceCoordinateMap) -> Bool {
        map.isSourceRangeVisible(sourceUTF16Range)
    }
}

public extension DefaultPreparedTextEngine {
    func displayLayoutPacket(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        containerWidth: CGFloat? = nil,
        env: MeasurementEnv = .default,
        options: PreparedTextLayoutOptions = .default
    ) -> PreparedTextDisplayPacket {
        let resolvedLayoutWidth = env.resolvedMeasurementWidth(maxWidth)
        let resolvedContainerWidth = max(containerWidth ?? resolvedLayoutWidth, resolvedLayoutWidth)
        let layoutPacket = layoutPacket(
            prepared,
            maxWidth: maxWidth,
            lineHeight: lineHeight,
            env: env,
            options: options
        )
        return PreparedTextDisplayLayoutBuilder(
            layoutPacket: layoutPacket,
            containerWidth: resolvedContainerWidth
        ).build()
    }

    func sourceCoordinateMap(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        containerWidth: CGFloat? = nil,
        env: MeasurementEnv = .default,
        options: PreparedTextLayoutOptions = .default
    ) -> PreparedTextSourceCoordinateMap {
        layoutPacket(
            prepared,
            maxWidth: maxWidth,
            lineHeight: lineHeight,
            env: env,
            options: options
        ).sourceCoordinateMap
    }
}

struct PreparedTextCoreLayoutBuilder {
    private struct TruncationComposition {
        var attributedText: NSAttributedString
        var sourceSpans: [PreparedTextSourceCoordinateSpan]
        var isTruncated: Bool
    }

    private let engine: DefaultPreparedTextEngine
    private let prepared: PreparedText
    private let layoutWidth: CGFloat
    private let requestedLineHeight: CGFloat
    private let options: PreparedTextLayoutOptions

    init(
        engine: DefaultPreparedTextEngine,
        prepared: PreparedText,
        layoutWidth: CGFloat,
        requestedLineHeight: CGFloat,
        options: PreparedTextLayoutOptions
    ) {
        self.engine = engine
        self.prepared = prepared
        self.layoutWidth = layoutWidth
        self.requestedLineHeight = requestedLineHeight
        self.options = options
    }

    func build() -> PreparedLayoutPacket {
        let maximumVisibleLines = options.maximumNumberOfLines > 0 ? options.maximumNumberOfLines : Int.max
        guard maximumVisibleLines > 0 else {
            return PreparedLayoutPacket(
                result: LayoutResult(fragments: [], height: 0, maxPaintWidth: 0),
                lines: [],
                sourceCoordinateMappingMode: prepared.sourceCoordinateMappingMode
            )
        }

        var drawLines: [PreparedDrawLine] = []
        drawLines.reserveCapacity(min(maximumVisibleLines, 8))

        var cursor = LayoutCursor()
        var stoppedEarly = false

        while drawLines.count < maximumVisibleLines,
              let line = engine.rawNextLine(
                  prepared,
                  cursor: cursor,
                  maxWidth: layoutWidth,
                  strategy: options.lineBreakStrategy
              ) {
            let reachedLastVisibleLine = options.maximumNumberOfLines > 0 && drawLines.count + 1 == maximumVisibleLines
            if reachedLastVisibleLine,
               engine.rawNextLine(
                   prepared,
                   cursor: line.end,
                   maxWidth: layoutWidth,
                   strategy: options.lineBreakStrategy
               ) != nil {
                drawLines.append(makeFinalVisibleLine(from: line))
                stoppedEarly = true
                break
            }

            drawLines.append(makeVisibleLine(from: line))
            cursor = line.end
        }

        let fragments = drawLines.map(\.fragment)
        let visibleRanges = drawLines.flatMap { line in
            line.sourceSpans.compactMap(\.sourceUTF16Range)
        }
        let result = LayoutResult(
            fragments: fragments,
            height: fragments.reduce(0) { $0 + $1.blockAdvance },
            maxPaintWidth: fragments.map(\.paintWidth).max() ?? 0,
            isTruncated: drawLines.contains(where: \.isTruncated),
            stoppedEarlyAtMaximumNumberOfLines: stoppedEarly,
            visibleSourceUTF16Ranges: visibleRanges
        )
        return PreparedLayoutPacket(
            result: result,
            lines: drawLines,
            sourceCoordinateMappingMode: prepared.sourceCoordinateMappingMode
        )
    }

    private func makeVisibleLine(from sourceLine: LineResult) -> PreparedDrawLine {
        let attributed = engine.attributedLine(prepared, line: sourceLine)
        let ctLine = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        let fragment = engine.buildFragment(
            for: prepared,
            line: sourceLine,
            attributedLine: attributed,
            ctLine: ctLine,
            requestedLineHeight: requestedLineHeight
        )
        let consumedRange = prepared.nsRange(from: sourceLine.start, to: sourceLine.end)
        let visibleRange = prepared.nsRange(from: sourceLine.start, to: sourceLine.paintEnd)
        return PreparedDrawLine(
            fragment: fragment,
            attributedText: attributed,
            ctLine: ctLine,
            isTruncated: false,
            consumedSourceUTF16Range: consumedRange,
            sourceSpans: [
                PreparedTextSourceCoordinateSpan(
                    displayUTF16Range: NSRange(location: 0, length: attributed.length),
                    sourceUTF16Range: visibleRange
                ),
            ],
            resolvedAlignment: resolvedAlignment(for: attributed)
        )
    }

    private func makeFinalVisibleLine(from sourceLine: LineResult) -> PreparedDrawLine {
        let baseLine = makeVisibleLine(from: sourceLine)
        let remainder = engine.attributedText(
            prepared,
            from: sourceLine.start,
            to: nil,
            flatteningHardBreaks: false
        )
        let truncationSource = truncationSourceText(from: remainder)
        let sourceBaseOffset = prepared.utf16Offset(for: sourceLine.start)
        let consumedSourceRange = NSRange(location: sourceBaseOffset, length: truncationSource.length)

        switch options.lineBreakMode {
        case .wordWrap, .characterWrap:
            var line = baseLine
            line.isTruncated = true
            line.consumedSourceUTF16Range = consumedSourceRange
            return line
        case .clip, .truncateHead, .truncateMiddle, .truncateTail:
            break
        }

        let forceTokenWhenFits = truncationSource.length < remainder.length
        let tokenAttributes = truncationTokenAttributes(sourceLine: baseLine, remainder: truncationSource)
        let composition = renderedTruncatedLine(
            source: truncationSource,
            sourceBaseOffset: sourceBaseOffset,
            width: layoutWidth,
            lineBreakMode: options.lineBreakMode,
            tokenAttributes: tokenAttributes,
            forceTokenWhenFits: forceTokenWhenFits
        )

        let ctLine = CTLineCreateWithAttributedString(composition.attributedText as CFAttributedString)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let measuredWidth = CGFloat(CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading))
        var fragment = baseLine.fragment
        fragment.fitWidth = min(layoutWidth, measuredWidth)
        fragment.paintWidth = min(layoutWidth, measuredWidth)
        fragment.trailingWhitespaceWidth = 0
        fragment.ascent = max(fragment.ascent, ascent)
        fragment.descent = max(fragment.descent, descent)
        fragment.leading = max(fragment.leading, leading)

        return PreparedDrawLine(
            fragment: fragment,
            attributedText: composition.attributedText,
            ctLine: ctLine,
            isTruncated: composition.isTruncated,
            consumedSourceUTF16Range: consumedSourceRange,
            sourceSpans: composition.sourceSpans,
            resolvedAlignment: resolvedAlignment(for: composition.attributedText)
        )
    }

    private func truncationSourceText(from remainder: NSAttributedString) -> NSAttributedString {
        let string = remainder.string as NSString
        let hardBreakRange = string.rangeOfCharacter(from: .newlines)
        guard hardBreakRange.location != NSNotFound else {
            return remainder
        }

        let prefixRange = NSRange(location: 0, length: hardBreakRange.location)
        guard prefixRange.length > 0 else {
            return NSAttributedString(string: "")
        }

        return remainder.attributedSubstring(from: prefixRange)
    }

    private func renderedTruncatedLine(
        source: NSAttributedString,
        sourceBaseOffset: Int,
        width: CGFloat,
        lineBreakMode: PreparedTextLineBreakMode,
        tokenAttributes: [NSAttributedString.Key: Any],
        forceTokenWhenFits: Bool
    ) -> TruncationComposition {
        guard source.length > 0 else {
            return TruncationComposition(attributedText: NSAttributedString(string: ""), sourceSpans: [], isTruncated: false)
        }

        let sourceWidth = lineWidth(for: source)
        let token = NSAttributedString(string: "…", attributes: tokenAttributes)

        switch lineBreakMode {
        case .wordWrap, .characterWrap:
            return TruncationComposition(
                attributedText: source,
                sourceSpans: [
                    PreparedTextSourceCoordinateSpan(
                        displayUTF16Range: NSRange(location: 0, length: source.length),
                        sourceUTF16Range: NSRange(location: sourceBaseOffset, length: source.length)
                    ),
                ],
                isTruncated: false
            )

        case .clip:
            guard sourceWidth > width else {
                return TruncationComposition(
                    attributedText: source,
                    sourceSpans: [
                        PreparedTextSourceCoordinateSpan(
                            displayUTF16Range: NSRange(location: 0, length: source.length),
                            sourceUTF16Range: NSRange(location: sourceBaseOffset, length: source.length)
                        ),
                    ],
                    isTruncated: false
                )
            }
            return clippedPrefixComposition(source: source, sourceBaseOffset: sourceBaseOffset, width: width)

        case .truncateTail:
            if sourceWidth <= width, !forceTokenWhenFits {
                return TruncationComposition(
                    attributedText: source,
                    sourceSpans: [
                        PreparedTextSourceCoordinateSpan(
                            displayUTF16Range: NSRange(location: 0, length: source.length),
                            sourceUTF16Range: NSRange(location: sourceBaseOffset, length: source.length)
                        ),
                    ],
                    isTruncated: false
                )
            }
            return truncatedTailComposition(source: source, token: token, sourceBaseOffset: sourceBaseOffset, width: width)

        case .truncateHead:
            if sourceWidth <= width, !forceTokenWhenFits {
                return TruncationComposition(
                    attributedText: source,
                    sourceSpans: [
                        PreparedTextSourceCoordinateSpan(
                            displayUTF16Range: NSRange(location: 0, length: source.length),
                            sourceUTF16Range: NSRange(location: sourceBaseOffset, length: source.length)
                        ),
                    ],
                    isTruncated: false
                )
            }
            return truncatedHeadComposition(source: source, token: token, sourceBaseOffset: sourceBaseOffset, width: width)

        case .truncateMiddle:
            if sourceWidth <= width, !forceTokenWhenFits {
                return TruncationComposition(
                    attributedText: source,
                    sourceSpans: [
                        PreparedTextSourceCoordinateSpan(
                            displayUTF16Range: NSRange(location: 0, length: source.length),
                            sourceUTF16Range: NSRange(location: sourceBaseOffset, length: source.length)
                        ),
                    ],
                    isTruncated: false
                )
            }
            return truncatedMiddleComposition(source: source, token: token, sourceBaseOffset: sourceBaseOffset, width: width)
        }
    }

    private func clippedPrefixComposition(
        source: NSAttributedString,
        sourceBaseOffset: Int,
        width: CGFloat
    ) -> TruncationComposition {
        let table = ComposedCharacterTable(string: source.string)
        var low = 0
        var high = table.count
        var bestRange = NSRange(location: 0, length: 0)

        while low <= high {
            let mid = (low + high) / 2
            let candidateRange = table.prefixUTF16Range(forCharacterCount: mid)
            let candidate = source.attributedSubstring(from: candidateRange)
            if lineWidth(for: candidate) <= width {
                bestRange = candidateRange
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let displayed = source.attributedSubstring(from: bestRange)
        let span = PreparedTextSourceCoordinateSpan(
            displayUTF16Range: NSRange(location: 0, length: displayed.length),
            sourceUTF16Range: NSRange(location: sourceBaseOffset + bestRange.location, length: bestRange.length)
        )
        return TruncationComposition(
            attributedText: displayed,
            sourceSpans: bestRange.length > 0 ? [span] : [],
            isTruncated: bestRange.length < source.length
        )
    }

    private func truncatedTailComposition(
        source: NSAttributedString,
        token: NSAttributedString,
        sourceBaseOffset: Int,
        width: CGFloat
    ) -> TruncationComposition {
        guard lineWidth(for: token) <= width else {
            return TruncationComposition(attributedText: NSAttributedString(string: ""), sourceSpans: [], isTruncated: true)
        }

        let table = ComposedCharacterTable(string: source.string)
        var low = 0
        var high = table.count
        var bestRange = NSRange(location: 0, length: 0)

        while low <= high {
            let mid = (low + high) / 2
            let candidateRange = table.prefixUTF16Range(forCharacterCount: mid)
            let candidate = NSMutableAttributedString(attributedString: source.attributedSubstring(from: candidateRange))
            candidate.append(token)
            if lineWidth(for: candidate) <= width {
                bestRange = candidateRange
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let displayed = NSMutableAttributedString(attributedString: source.attributedSubstring(from: bestRange))
        let prefixLength = displayed.length
        displayed.append(token)
        var spans: [PreparedTextSourceCoordinateSpan] = []
        if bestRange.length > 0 {
            spans.append(
                PreparedTextSourceCoordinateSpan(
                    displayUTF16Range: NSRange(location: 0, length: prefixLength),
                    sourceUTF16Range: NSRange(location: sourceBaseOffset + bestRange.location, length: bestRange.length)
                )
            )
        }
        spans.append(
            PreparedTextSourceCoordinateSpan(
                displayUTF16Range: NSRange(location: prefixLength, length: token.length),
                sourceUTF16Range: nil
            )
        )
        return TruncationComposition(attributedText: displayed, sourceSpans: spans, isTruncated: true)
    }

    private func truncatedHeadComposition(
        source: NSAttributedString,
        token: NSAttributedString,
        sourceBaseOffset: Int,
        width: CGFloat
    ) -> TruncationComposition {
        guard lineWidth(for: token) <= width else {
            return TruncationComposition(attributedText: NSAttributedString(string: ""), sourceSpans: [], isTruncated: true)
        }

        let table = ComposedCharacterTable(string: source.string)
        var low = 0
        var high = table.count
        var bestRange = NSRange(location: source.length, length: 0)

        while low <= high {
            let mid = (low + high) / 2
            let candidateRange = table.suffixUTF16Range(forCharacterCount: mid)
            let candidate = NSMutableAttributedString(attributedString: token)
            candidate.append(source.attributedSubstring(from: candidateRange))
            if lineWidth(for: candidate) <= width {
                bestRange = candidateRange
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let displayed = NSMutableAttributedString(attributedString: token)
        displayed.append(source.attributedSubstring(from: bestRange))
        var spans: [PreparedTextSourceCoordinateSpan] = [
            PreparedTextSourceCoordinateSpan(
                displayUTF16Range: NSRange(location: 0, length: token.length),
                sourceUTF16Range: nil
            ),
        ]
        if bestRange.length > 0 {
            spans.append(
                PreparedTextSourceCoordinateSpan(
                    displayUTF16Range: NSRange(location: token.length, length: bestRange.length),
                    sourceUTF16Range: NSRange(location: sourceBaseOffset + bestRange.location, length: bestRange.length)
                )
            )
        }
        return TruncationComposition(attributedText: displayed, sourceSpans: spans, isTruncated: true)
    }

    private func truncatedMiddleComposition(
        source: NSAttributedString,
        token: NSAttributedString,
        sourceBaseOffset: Int,
        width: CGFloat
    ) -> TruncationComposition {
        guard lineWidth(for: token) <= width else {
            return TruncationComposition(attributedText: NSAttributedString(string: ""), sourceSpans: [], isTruncated: true)
        }

        let table = ComposedCharacterTable(string: source.string)
        var low = 0
        var high = table.count
        var bestKeepCount = 0

        while low <= high {
            let mid = (low + high) / 2
            let candidate = middleTruncationCandidate(source: source, token: token, table: table, keptCharacterCount: mid)
            if lineWidth(for: candidate.attributedText) <= width {
                bestKeepCount = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let candidate = middleTruncationCandidate(source: source, token: token, table: table, keptCharacterCount: bestKeepCount)
        let resolvedSpans = candidate.sourceSpans.map { span in
            PreparedTextSourceCoordinateSpan(
                displayUTF16Range: span.displayUTF16Range,
                sourceUTF16Range: span.sourceUTF16Range.map {
                    NSRange(location: sourceBaseOffset + $0.location, length: $0.length)
                }
            )
        }
        return TruncationComposition(attributedText: candidate.attributedText, sourceSpans: resolvedSpans, isTruncated: true)
    }

    private func middleTruncationCandidate(
        source: NSAttributedString,
        token: NSAttributedString,
        table: ComposedCharacterTable,
        keptCharacterCount: Int
    ) -> TruncationComposition {
        let clamped = max(min(keptCharacterCount, table.count), 0)
        let frontCount = (clamped + 1) / 2
        let backCount = clamped - frontCount
        let frontRange = table.prefixUTF16Range(forCharacterCount: frontCount)
        let backRange = table.suffixUTF16Range(forCharacterCount: backCount)

        let result = NSMutableAttributedString()
        var spans: [PreparedTextSourceCoordinateSpan] = []
        var displayLocation = 0

        if frontRange.length > 0 {
            let front = source.attributedSubstring(from: frontRange)
            result.append(front)
            spans.append(
                PreparedTextSourceCoordinateSpan(
                    displayUTF16Range: NSRange(location: displayLocation, length: front.length),
                    sourceUTF16Range: frontRange
                )
            )
            displayLocation += front.length
        }

        result.append(token)
        spans.append(
            PreparedTextSourceCoordinateSpan(
                displayUTF16Range: NSRange(location: displayLocation, length: token.length),
                sourceUTF16Range: nil
            )
        )
        displayLocation += token.length

        if backRange.length > 0 {
            let back = source.attributedSubstring(from: backRange)
            result.append(back)
            spans.append(
                PreparedTextSourceCoordinateSpan(
                    displayUTF16Range: NSRange(location: displayLocation, length: back.length),
                    sourceUTF16Range: backRange
                )
            )
        }

        return TruncationComposition(attributedText: result, sourceSpans: spans, isTruncated: true)
    }

    private func lineWidth(for attributedText: NSAttributedString) -> CGFloat {
        let line = CTLineCreateWithAttributedString(attributedText as CFAttributedString)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private func truncationTokenAttributes(
        sourceLine: PreparedDrawLine,
        remainder: NSAttributedString
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any]
        if sourceLine.attributedText.length > 0 {
            attributes = sourceLine.attributedText.attributes(
                at: sourceLine.attributedText.length - 1,
                effectiveRange: nil
            )
        } else if remainder.length > 0 {
            attributes = remainder.attributes(at: remainder.length - 1, effectiveRange: nil)
        } else {
            attributes = [:]
        }

        attributes[.link] = nil
        return attributes
    }

    private func resolvedAlignment(for attributedText: NSAttributedString) -> PreparedTextHorizontalAlignment {
        switch options.alignment {
        case .center:
            return .center
        case .left, .right:
            return options.alignment
        case .leading:
            return resolvedDirection(for: attributedText) == .rightToLeft ? .right : .left
        case .trailing:
            return resolvedDirection(for: attributedText) == .rightToLeft ? .left : .right
        case .natural:
            break
        }

        let paragraphAlignment = (attributedText.length > 0
            ? (attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment
            : nil) ?? .natural

        switch paragraphAlignment {
        case .center:
            return .center
        case .right:
            return .right
        case .left:
            return .left
        case .natural, .justified:
            return resolvedDirection(for: attributedText) == .rightToLeft ? .right : .left
        @unknown default:
            return resolvedDirection(for: attributedText) == .rightToLeft ? .right : .left
        }
    }

    private func resolvedDirection(for attributedText: NSAttributedString) -> PreparedTextLayoutDirection {
        let baseDirection = (attributedText.length > 0
            ? (attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.baseWritingDirection
            : nil) ?? .natural
        switch baseDirection {
        case .rightToLeft:
            return .rightToLeft
        case .leftToRight:
            return .leftToRight
        default:
            break
        }

        switch options.layoutDirection {
        case .rightToLeft:
            return .rightToLeft
        case .leftToRight, .natural:
            return .leftToRight
        }
    }
}

private struct PreparedTextDisplayLayoutBuilder {
    private let layoutPacket: PreparedLayoutPacket
    private let containerWidth: CGFloat

    init(
        layoutPacket: PreparedLayoutPacket,
        containerWidth: CGFloat
    ) {
        self.layoutPacket = layoutPacket
        self.containerWidth = containerWidth
    }

    func build() -> PreparedTextDisplayPacket {
        guard !layoutPacket.lines.isEmpty else {
            return PreparedTextDisplayPacket(
                result: layoutPacket.result,
                lines: [],
                sourceCoordinateMappingMode: layoutPacket.sourceCoordinateMappingMode
            )
        }

        var lines: [PreparedTextDisplayLine] = []
        lines.reserveCapacity(layoutPacket.lines.count)

        for sourceLine in layoutPacket.lines {
            lines.append(makeDisplayLine(from: sourceLine))
        }

        return PreparedTextDisplayPacket(
            result: layoutPacket.result,
            lines: lines,
            sourceCoordinateMappingMode: layoutPacket.sourceCoordinateMappingMode
        )
    }

    private func makeDisplayLine(from sourceLine: PreparedDrawLine) -> PreparedTextDisplayLine {
        let originX = horizontalOrigin(
            alignment: sourceLine.resolvedAlignment,
            lineWidth: sourceLine.fragment.paintWidth,
            containerWidth: containerWidth
        )
        return PreparedTextDisplayLine(
            fragment: sourceLine.fragment,
            attributedText: sourceLine.attributedText,
            ctLine: sourceLine.ctLine,
            lineWidth: sourceLine.fragment.paintWidth,
            originX: originX,
            isTruncated: sourceLine.isTruncated,
            consumedSourceUTF16Range: sourceLine.consumedSourceUTF16Range,
            sourceSpans: sourceLine.sourceSpans
        )
    }
    private func horizontalOrigin(
        alignment: PreparedTextHorizontalAlignment,
        lineWidth: CGFloat,
        containerWidth: CGFloat
    ) -> CGFloat {
        preparedCoordinateHorizontalOrigin(
            alignment: alignment,
            lineWidth: lineWidth,
            containerWidth: containerWidth
        )
    }
}

func preparedCoordinateHorizontalOrigin(
    alignment: PreparedTextHorizontalAlignment,
    lineWidth: CGFloat,
    containerWidth: CGFloat
) -> CGFloat {
    switch alignment {
    case .center:
        return max((containerWidth - lineWidth) / 2, 0)
    case .right:
        return max(containerWidth - lineWidth, 0)
    case .left, .leading, .trailing, .natural:
        return 0
    }
}

func preparedCoordinateDisplayFrame(
    originX: CGFloat,
    originY: CGFloat,
    lineWidth: CGFloat,
    fragment: LineFragment
) -> CGRect {
    let typographicTop = originY + fragment.paragraphSpacingBefore
    let typographicHeight = max(fragment.ascent + fragment.descent + fragment.leading, 1)
    return CGRect(x: originX, y: typographicTop, width: lineWidth, height: typographicHeight)
}

func preparedCoordinateSpans(
    from spans: [PreparedTextSourceCoordinateSpan],
    attributedText: NSAttributedString,
    ctLine: CTLine,
    originX: CGFloat,
    originY: CGFloat,
    lineWidth: CGFloat,
    fragment: LineFragment
) -> [PreparedTextSourceCoordinateSpan] {
    spans.flatMap { span -> [PreparedTextSourceCoordinateSpan] in
        guard
            let sourceRange = span.sourceUTF16Range,
            sourceRange.length == span.displayUTF16Range.length,
            sourceRange.length > 1
        else {
            return [
                PreparedTextSourceCoordinateSpan(
                    displayUTF16Range: span.displayUTF16Range,
                    sourceUTF16Range: span.sourceUTF16Range,
                    displayRect: preparedCoordinateRect(
                        for: span.displayUTF16Range,
                        ctLine: ctLine,
                        originX: originX,
                        originY: originY,
                        lineWidth: lineWidth,
                        fragment: fragment
                    )
                ),
            ]
        }

        let displayNSString = attributedText.string as NSString
        let spanEnd = NSMaxRange(span.displayUTF16Range)
        var slices: [PreparedTextSourceCoordinateSpan] = []
        var cursor = span.displayUTF16Range.location

        while cursor < spanEnd {
            let displaySlice = displayNSString.rangeOfComposedCharacterSequence(at: cursor)
            let clampedLength = min(NSMaxRange(displaySlice), spanEnd) - cursor
            let resolvedDisplaySlice = NSRange(location: cursor, length: max(clampedLength, 0))
            guard resolvedDisplaySlice.length > 0 else {
                cursor += 1
                continue
            }

            let delta = resolvedDisplaySlice.location - span.displayUTF16Range.location
            let sourceSlice = NSRange(location: sourceRange.location + delta, length: resolvedDisplaySlice.length)
            slices.append(
                PreparedTextSourceCoordinateSpan(
                    displayUTF16Range: resolvedDisplaySlice,
                    sourceUTF16Range: sourceSlice,
                    displayRect: preparedCoordinateRect(
                        for: resolvedDisplaySlice,
                        ctLine: ctLine,
                        originX: originX,
                        originY: originY,
                        lineWidth: lineWidth,
                        fragment: fragment
                    )
                )
            )
            cursor = NSMaxRange(resolvedDisplaySlice)
        }

        return slices.isEmpty ? [
            PreparedTextSourceCoordinateSpan(
                displayUTF16Range: span.displayUTF16Range,
                sourceUTF16Range: span.sourceUTF16Range,
                displayRect: preparedCoordinateRect(
                    for: span.displayUTF16Range,
                    ctLine: ctLine,
                    originX: originX,
                    originY: originY,
                    lineWidth: lineWidth,
                    fragment: fragment
                )
            ),
        ] : slices
    }
}

func preparedCoordinateRect(
    for displayUTF16Range: NSRange,
    ctLine: CTLine,
    originX: CGFloat,
    originY: CGFloat,
    lineWidth: CGFloat,
    fragment: LineFragment
) -> CGRect? {
    guard displayUTF16Range.length > 0 else {
        return nil
    }

    let lineLength = CTLineGetStringRange(ctLine).length
    let displayEnd = min(NSMaxRange(displayUTF16Range), lineLength)
    let displayStart = min(max(displayUTF16Range.location, 0), displayEnd)
    guard displayEnd > displayStart else {
        return nil
    }

    let localStart = CGFloat(CTLineGetOffsetForStringIndex(ctLine, displayStart, nil))
    let localEnd: CGFloat
    if displayEnd >= lineLength {
        localEnd = lineWidth
    } else {
        localEnd = CGFloat(CTLineGetOffsetForStringIndex(ctLine, displayEnd, nil))
    }

    let minLocalX = min(localStart, localEnd)
    let rect = preparedCoordinateDisplayFrame(
        originX: originX,
        originY: originY,
        lineWidth: abs(localEnd - localStart),
        fragment: fragment
    ).offsetBy(dx: minLocalX, dy: 0)
    return rect.isNull || rect.isEmpty ? nil : rect
}

private struct ComposedCharacterTable {
    private let ranges: [NSRange]

    init(string: String) {
        let nsString = string as NSString
        var collected: [NSRange] = []
        nsString.enumerateSubstrings(
            in: NSRange(location: 0, length: nsString.length),
            options: .byComposedCharacterSequences
        ) { _, range, _, _ in
            collected.append(range)
        }
        ranges = collected
    }

    var count: Int {
        ranges.count
    }

    func prefixUTF16Range(forCharacterCount count: Int) -> NSRange {
        guard count > 0, !ranges.isEmpty else {
            return NSRange(location: 0, length: 0)
        }
        let clamped = min(count, ranges.count)
        let end = NSMaxRange(ranges[clamped - 1])
        return NSRange(location: 0, length: end)
    }

    func suffixUTF16Range(forCharacterCount count: Int) -> NSRange {
        guard count > 0, !ranges.isEmpty else {
            return NSRange(location: ranges.last.map(NSMaxRange) ?? 0, length: 0)
        }
        let clamped = min(count, ranges.count)
        let start = ranges[ranges.count - clamped].location
        let end = NSMaxRange(ranges.last!)
        return NSRange(location: start, length: end - start)
    }
}

private extension PreparedText {
    func nsRange(from start: LayoutCursor, to end: LayoutCursor) -> NSRange {
        let startOffset = utf16Offset(for: start)
        let endOffset = utf16Offset(for: end)
        return NSRange(location: startOffset, length: max(endOffset - startOffset, 0))
    }
}

private func preparedMergedRanges(_ ranges: [NSRange]) -> [NSRange] {
    let normalized = ranges
        .filter { $0.length > 0 }
        .sorted { lhs, rhs in
            if lhs.location == rhs.location {
                return lhs.length < rhs.length
            }
            return lhs.location < rhs.location
        }

    guard var current = normalized.first else {
        return []
    }

    var merged: [NSRange] = []
    for range in normalized.dropFirst() {
        if range.location <= NSMaxRange(current) {
            current.length = max(NSMaxRange(current), NSMaxRange(range)) - current.location
        } else {
            merged.append(current)
            current = range
        }
    }
    merged.append(current)
    return merged
}
