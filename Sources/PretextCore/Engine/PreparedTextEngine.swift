import CoreGraphics
import CoreText
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public protocol PreparedTextEngine: AnyObject {
    func prepare(_ attributedText: NSAttributedString, options: PreparedTextOptions) -> PreparedText
    func prepare(_ attributedText: NSAttributedString, sourceID: PreparedTextSourceID, options: PreparedTextOptions) -> PreparedText
    func layout(_ prepared: PreparedText, maxWidth: CGFloat, lineHeight: CGFloat) -> LayoutResult
    func layout(_ prepared: PreparedText, maxWidth: CGFloat, lineHeight: CGFloat, env: MeasurementEnv) -> LayoutResult
    func layout(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        env: MeasurementEnv,
        options: PreparedTextLayoutOptions
    ) -> LayoutResult
    func nextLine(_ prepared: PreparedText, cursor: LayoutCursor, maxWidth: CGFloat) -> LineResult?
    func attributedLine(_ prepared: PreparedText, line: LineResult) -> NSAttributedString
    func attributedText(_ prepared: PreparedText, from start: LayoutCursor, to end: LayoutCursor?, flatteningHardBreaks: Bool) -> NSAttributedString
    func invalidateCaches()
    func diagnosticsSnapshot() -> PreparedTextDiagnosticsSnapshot
}

public extension PreparedTextEngine {
    func layout(_ prepared: PreparedText, maxWidth: CGFloat, lineHeight: CGFloat, env: MeasurementEnv) -> LayoutResult {
        layout(prepared, maxWidth: maxWidth, lineHeight: lineHeight)
    }

    func layout(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        env: MeasurementEnv,
        options _: PreparedTextLayoutOptions
    ) -> LayoutResult {
        layout(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: env)
    }

    func diagnosticsSnapshot() -> PreparedTextDiagnosticsSnapshot {
        PreparedTextDiagnosticsSnapshot(
            measurementCache: MeasurementStats(),
            preparedTextCache: CacheDiagnosticsSnapshot(),
            layoutPacketCache: CacheDiagnosticsSnapshot(),
            segmentMeasurementCache: CacheDiagnosticsSnapshot()
        )
    }
}

public final class DefaultPreparedTextEngine: PreparedTextEngine {
    public let measurer: CachedFramesetterTextMeasurer
    public let attachmentResolver: PreparedAttachmentResolving?

    private let segmentMeasurementCache = SegmentMeasurementCache()
    private let preparedTextCache = CostBoundCache<PreparedTextCacheKey, PreparedText>(
        countLimit: 256,
        totalCostLimit: 8 * 1_024 * 1_024,
        cost: { prepared in
            max(prepared.storage.source.length, 1) * 4
                + prepared.storage.core.segments.count * 48
                + prepared.storage.layoutIdentity.signature.attachmentCount * 384
        }
    )
    private let layoutPacketCache = CostBoundCache<LayoutPacketKey, PreparedLayoutPacket>(
        countLimit: 512,
        totalCostLimit: 12 * 1_024 * 1_024,
        cost: { packet in
            let textBytes = packet.lines.reduce(into: 0) { partialResult, line in
                partialResult += max(line.attributedText.length, 1) * 4
            }
            let lineCost = packet.result.fragments.reduce(0) { partialResult, fragment in
                partialResult + Int((fragment.paintWidth + fragment.blockAdvance).rounded(.up))
            }
            return max(textBytes + packet.lines.count * 96 + lineCost, 1)
        }
    )
    private var invalidationStats = PreparedTextInvalidationStats()
    private var layoutPacketReuseCount = 0
    private var observedLayoutLineCount = 0
    private var observedLayoutCount = 0

    public init(
        measurer: CachedFramesetterTextMeasurer = CachedFramesetterTextMeasurer(),
        attachmentResolver: PreparedAttachmentResolving? = PreparedAttachmentRegistry.shared
    ) {
        self.measurer = measurer
        self.attachmentResolver = attachmentResolver
    }

    public func prepare(_ attributedText: NSAttributedString, options: PreparedTextOptions = PreparedTextOptions()) -> PreparedText {
        prepare(attributedText, sourceID: nil, options: options)
    }

    public func prepare(
        _ attributedText: NSAttributedString,
        sourceID: PreparedTextSourceID,
        options: PreparedTextOptions = PreparedTextOptions()
    ) -> PreparedText {
        prepare(attributedText, sourceID: sourceID as PreparedTextSourceID?, options: options)
    }

    public func layout(_ prepared: PreparedText, maxWidth: CGFloat, lineHeight: CGFloat) -> LayoutResult {
        layout(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: .default, options: .default)
    }

    public func layout(_ prepared: PreparedText, maxWidth: CGFloat, lineHeight: CGFloat, env: MeasurementEnv) -> LayoutResult {
        layout(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: env, options: .default)
    }

    public func layout(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        env: MeasurementEnv,
        options: PreparedTextLayoutOptions
    ) -> LayoutResult {
        layoutPacket(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: env, options: options).result
    }

    public func layoutPacket(_ prepared: PreparedText, maxWidth: CGFloat, lineHeight: CGFloat) -> PreparedLayoutPacket {
        layoutPacket(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: .default, options: .default)
    }

    public func layoutPacket(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        env: MeasurementEnv
    ) -> PreparedLayoutPacket {
        layoutPacket(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: env, options: .default)
    }

    public func layoutPacket(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        env: MeasurementEnv,
        options: PreparedTextLayoutOptions
    ) -> PreparedLayoutPacket {
        let resolvedLineHeight = lineHeight > 0 ? lineHeight : prepared.defaultLineHeight
        guard maxWidth >= 0 else {
            return PreparedLayoutPacket(result: LayoutResult(fragments: [], height: 0, maxPaintWidth: 0), lines: [])
        }

        let resolvedWidth = env.resolvedMeasurementWidth(maxWidth)
        let key = LayoutPacketKey(
            identity: prepared.storage.layoutIdentity,
            widthInPixels: env.normalizedWidth(maxWidth),
            lineHeightKey: env.cacheScalarKey(resolvedLineHeight),
            context: MeasurementCacheContext(env: env),
            preparedTextOptions: PreparedTextOptionsCacheContext(options: prepared.storage.options),
            layoutOptions: options
        )

        if let cached = layoutPacketCache.value(forKey: key) {
            layoutPacketReuseCount += 1
            recordObservedLayout(cached.result.lineCount)
            return cached
        }

        let packet = PreparedTextSignposts.measure("Stage1LayoutPacket") {
            PreparedTextCoreLayoutBuilder(
                engine: self,
                prepared: prepared,
                layoutWidth: resolvedWidth,
                requestedLineHeight: resolvedLineHeight,
                options: options
            ).build()
        }
        layoutPacketCache.insert(packet, forKey: key)
        recordObservedLayout(packet.result.lineCount)
        return packet
    }

    public func nextLine(_ prepared: PreparedText, cursor: LayoutCursor, maxWidth: CGFloat) -> LineResult? {
        guard var line = rawNextLine(prepared, cursor: cursor, maxWidth: maxWidth) else {
            return nil
        }

        line.text = sanitizedRenderedLineText(attributedLine(prepared, line: line).string)
        return line
    }

    public func nextLineLayoutOnly(_ prepared: PreparedText, cursor: LayoutCursor, maxWidth: CGFloat) -> LineResult? {
        rawNextLine(prepared, cursor: cursor, maxWidth: maxWidth)
    }

    public func attributedLine(_ prepared: PreparedText, line: LineResult) -> NSAttributedString {
        materializedAttributedText(
            prepared,
            from: line.start,
            to: line.paintEnd,
            flatteningHardBreaks: false,
            discretionaryHyphenSegmentIndex: line.discretionaryHyphenSegmentIndex
        )
    }

    public func attributedText(
        _ prepared: PreparedText,
        from start: LayoutCursor,
        to end: LayoutCursor? = nil,
        flatteningHardBreaks: Bool = false
    ) -> NSAttributedString {
        materializedAttributedText(
            prepared,
            from: start,
            to: end,
            flatteningHardBreaks: flatteningHardBreaks,
            discretionaryHyphenSegmentIndex: nil
        )
    }

    private func materializedAttributedText(
        _ prepared: PreparedText,
        from start: LayoutCursor,
        to end: LayoutCursor?,
        flatteningHardBreaks: Bool,
        discretionaryHyphenSegmentIndex: Int?
    ) -> NSAttributedString {
        let core = prepared.storage.core
        let mutable = NSMutableAttributedString(string: "")
        var cursor = start
        var containsTab = false
        let terminalCursor = end ?? LayoutCursor(segmentIndex: core.segments.count, graphemeIndex: 0)

        while cursor < terminalCursor {
            let segment = core.segments[cursor.segmentIndex]
            switch segment.kind {
            case .word, .punctuationPrefix, .punctuationSuffix, .urlLike, .cjkRun, .whitespace, .glue:
                let startIndex = cursor.graphemeIndex
                let endIndex: Int
                if cursor.segmentIndex == terminalCursor.segmentIndex {
                    endIndex = terminalCursor.graphemeIndex
                } else {
                    endIndex = segment.graphemeCount
                }

                if endIndex > startIndex {
                    mutable.append(segment.slice(from: startIndex, to: endIndex))
                }
                cursor = cursorAdvancingFromTextSegment(
                    segmentIndex: cursor.segmentIndex,
                    endIndex: endIndex,
                    graphemeCount: segment.graphemeCount
                )

            case .tab:
                containsTab = true
                mutable.append(segment.attributedText)
                cursor = LayoutCursor(segmentIndex: cursor.segmentIndex + 1, graphemeIndex: 0)

            case .zeroWidthBreak, .softHyphen:
                cursor = LayoutCursor(segmentIndex: cursor.segmentIndex + 1, graphemeIndex: 0)

            case .hardBreak:
                if flatteningHardBreaks {
                    appendFlattenedHardBreak(from: segment, into: mutable)
                } else {
                    mutable.append(segment.attributedText)
                }
                cursor = LayoutCursor(segmentIndex: cursor.segmentIndex + 1, graphemeIndex: 0)
            }
        }

        if let discretionaryHyphenSegmentIndex,
           core.segments.indices.contains(discretionaryHyphenSegmentIndex) {
            let hyphenSegment = core.segments[discretionaryHyphenSegmentIndex]
            let hyphen = NSAttributedString(
                string: "-",
                attributes: hyphenSegment.attributedText.length > 0
                    ? hyphenSegment.attributedText.attributes(at: 0, effectiveRange: nil)
                    : [:]
            )
            mutable.append(hyphen)
        }

        if containsTab {
            applyTabLayoutAttributes(to: mutable, tabStopAdvance: core.tabStopAdvance)
        }

        return mutable.copy() as? NSAttributedString ?? mutable
    }

    public func invalidateCaches() {
        invalidateCaches(reason: .manual)
    }

    public func diagnosticsSnapshot() -> PreparedTextDiagnosticsSnapshot {
        PreparedTextDiagnosticsSnapshot(
            measurementCache: measurer.stats,
            preparedTextCache: preparedTextCache.snapshot,
            layoutPacketCache: layoutPacketCache.snapshot,
            segmentMeasurementCache: segmentMeasurementCache.snapshot,
            layoutPacketReuseCount: layoutPacketReuseCount,
            averageLinesPerLayout: observedLayoutCount > 0
                ? Double(observedLayoutLineCount) / Double(observedLayoutCount)
                : 0,
            invalidations: invalidationStats
        )
    }

    func invalidateCaches(reason: PreparedInvalidationReason) {
        preparedTextCache.removeAll()
        layoutPacketCache.removeAll()
        measurer.invalidateAll()
        segmentMeasurementCache.invalidateAll()
        invalidationStats.fullInvalidationCount += 1
        invalidationStats.lastReason = reason
    }

    func invalidateCaches(sourceIDs: Set<PreparedTextSourceID>, reason: PreparedInvalidationReason) {
        guard !sourceIDs.isEmpty else {
            return
        }

        preparedTextCache.removeAll { key, _ in
            guard let sourceID = key.identity.sourceID else {
                return false
            }
            return sourceIDs.contains(sourceID)
        }
        layoutPacketCache.removeAll { key, _ in
            guard let sourceID = key.identity.sourceID else {
                return false
            }
            return sourceIDs.contains(sourceID)
        }
        segmentMeasurementCache.invalidate(sourceIDs: sourceIDs)
        measurer.invalidate(sourceIDs: sourceIDs)
        invalidationStats.targetedInvalidationCount += 1
        invalidationStats.lastReason = reason
    }

    func trimForBackground(reason: PreparedInvalidationReason = .backgroundTrim) {
        let layoutSnapshot = layoutPacketCache.snapshot
        layoutPacketCache.trim(
            countLimit: layoutSnapshot.countLimit.map { max($0 / 2, 1) },
            totalCostLimit: layoutSnapshot.totalCostLimit.map { max($0 / 2, 1) }
        )
        measurer.trimForBackground()
        segmentMeasurementCache.trimForBackground()
        invalidationStats.backgroundTrimCount += 1
        invalidationStats.lastReason = reason
    }

    private func prepare(
        _ attributedText: NSAttributedString,
        sourceID: PreparedTextSourceID?,
        options: PreparedTextOptions
    ) -> PreparedText {
        let resolvedSource = resolvedAttachmentSource(from: attributedText, sourceID: sourceID)
        let signature = resolvedSource.pretextLayoutSignature()
        let key = PreparedTextCacheKey(
            identity: sourceID.map { CacheIdentity.sourceID($0, signature) } ?? .attributed(signature),
            whiteSpaceMode: options.whiteSpaceMode,
            localeIdentifier: options.localeIdentifier
        )

        if let cached = preparedTextCache.value(forKey: key),
           cached.storage.layoutIdentity.signature == signature {
            return cached
        }

        let prepared = PreparedTextSignposts.measure("Stage1Prepare") {
            let sourceSnapshot = resolvedSource.copy() as? NSAttributedString ?? NSAttributedString(attributedString: resolvedSource)
            let segmenter = TextSegmenter(options: options, segmentMeasurementCache: segmentMeasurementCache)
            let preservesSourceCoordinateSpace = segmenter.preservesSourceCoordinateSpace(for: sourceSnapshot)
            let core = PreparedTextCore(
                segments: segmenter.segment(sourceSnapshot),
                defaultLineHeight: segmenter.defaultLineHeight(for: sourceSnapshot),
                tabStopAdvance: segmenter.tabStopAdvance(for: sourceSnapshot),
                prefersNativeLineBreaking: preservesSourceCoordinateSpace
                    && preferredNativeLineBreaking(for: sourceSnapshot.string),
                preservesSourceCoordinateSpace: preservesSourceCoordinateSpace
            )
            let nativeSource = nativeLineBreakingSource(
                from: sourceSnapshot,
                tabStopAdvance: core.tabStopAdvance,
                preservesSourceCoordinateSpace: preservesSourceCoordinateSpace
            )
            return PreparedText(
                storage: PreparedTextStorage(
                    source: sourceSnapshot,
                    core: core,
                    options: options,
                    sourceID: sourceID,
                    layoutIdentity: key.identity,
                    nativeLineBreakingSource: nativeSource,
                    nativeTypesetter: nativeSource.map { CTTypesetterCreateWithAttributedString($0 as CFAttributedString) }
                )
            )
        }
        preparedTextCache.insert(prepared, forKey: key)
        return prepared
    }

    func rawNextLine(
        _ prepared: PreparedText,
        cursor: LayoutCursor,
        maxWidth: CGFloat,
        strategy: PreparedTextLineBreakStrategy = .automatic
    ) -> LineResult? {
        if shouldUseNativeLineBreaking(for: prepared, strategy: strategy),
           let nativeLine = nativeNextLine(prepared, cursor: cursor, maxWidth: maxWidth),
           nativeLine.end > cursor {
            return nativeLine
        }
        let walker = TextLineWalker(core: prepared.storage.core, options: prepared.storage.options)
        return walker.nextLine(from: cursor, maxWidth: maxWidth)
    }

    func buildFragment(
        for prepared: PreparedText,
        line: LineResult,
        attributedLine: NSAttributedString,
        ctLine: CTLine,
        requestedLineHeight: CGFloat
    ) -> LineFragment {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        _ = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)

        let attributes = lineAttributes(for: prepared, line: line, attributedLine: attributedLine)
        let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle
        let naturalLineHeight = max(maximumFontLineHeight(in: attributedLine), ascent + descent + leading)
        let baseAdvance = resolvedLineHeight(
            requestedLineHeight: requestedLineHeight,
            naturalLineHeight: naturalLineHeight,
            paragraphStyle: paragraphStyle
        )
        let isParagraphStart = line.start.segmentIndex == 0 || previousSegmentKind(in: prepared, before: line.start) == .hardBreak
        let isParagraphEnd = line.end.segmentIndex >= prepared.storage.core.segments.count || previousSegmentKind(in: prepared, before: line.end) == .hardBreak
        let paragraphSpacingBefore = isParagraphStart ? paragraphStyle?.paragraphSpacingBefore ?? 0 : 0
        let paragraphSpacingAfter = isParagraphEnd ? paragraphStyle?.paragraphSpacing ?? 0 : 0
        let interLineSpacing = isParagraphEnd ? 0 : paragraphStyle?.lineSpacing ?? 0
        let blockAdvance = baseAdvance + paragraphSpacingBefore + paragraphSpacingAfter + interLineSpacing

        return LineFragment(
            start: line.start,
            end: line.end,
            paintEnd: line.paintEnd,
            fitWidth: line.width,
            paintWidth: line.paintWidth,
            trailingWhitespaceWidth: max(line.width - line.paintWidth, 0),
            ascent: ascent,
            descent: descent,
            leading: leading,
            blockAdvance: blockAdvance,
            paragraphSpacingBefore: paragraphSpacingBefore,
            paragraphSpacingAfter: paragraphSpacingAfter
        )
    }

    private func lineAttributes(
        for prepared: PreparedText,
        line: LineResult,
        attributedLine: NSAttributedString
    ) -> [NSAttributedString.Key: Any] {
        if attributedLine.length > 0 {
            return attributedLine.attributes(at: 0, effectiveRange: nil)
        }

        if prepared.storage.core.segments.indices.contains(line.start.segmentIndex) {
            return prepared.storage.core.segments[line.start.segmentIndex].attributedText.attributes(at: 0, effectiveRange: nil)
        }

        let fallbackIndex = max(line.start.segmentIndex - 1, 0)
        if prepared.storage.core.segments.indices.contains(fallbackIndex) {
            return prepared.storage.core.segments[fallbackIndex].attributedText.attributes(at: 0, effectiveRange: nil)
        }

        return [:]
    }

    private func previousSegmentKind(in prepared: PreparedText, before cursor: LayoutCursor) -> SegmentKind? {
        let index = cursor.segmentIndex - 1
        guard prepared.storage.core.segments.indices.contains(index) else {
            return nil
        }
        return prepared.storage.core.segments[index].kind
    }

    private func resolvedLineHeight(
        requestedLineHeight: CGFloat,
        naturalLineHeight: CGFloat,
        paragraphStyle: NSParagraphStyle?
    ) -> CGFloat {
        var resolved = requestedLineHeight > 0 ? requestedLineHeight : naturalLineHeight
        guard let paragraphStyle else {
            return resolved
        }

        if requestedLineHeight <= 0, paragraphStyle.lineHeightMultiple > 0 {
            resolved = max(resolved, naturalLineHeight * paragraphStyle.lineHeightMultiple)
        }
        if paragraphStyle.minimumLineHeight > 0 {
            resolved = max(resolved, paragraphStyle.minimumLineHeight)
        }
        if paragraphStyle.maximumLineHeight > 0 {
            resolved = min(resolved, max(paragraphStyle.maximumLineHeight, paragraphStyle.minimumLineHeight))
        }
        return resolved
    }

    private func maximumFontLineHeight(in attributedLine: NSAttributedString) -> CGFloat {
        guard attributedLine.length > 0 else {
            return 0
        }

        var maximum: CGFloat = 0
        attributedLine.enumerateAttributes(in: NSRange(location: 0, length: attributedLine.length), options: []) { attributes, _, _ in
            maximum = max(maximum, fontLineHeight(from: attributes))
        }
        return maximum
    }

    private func sanitizedRenderedLineText(_ text: String) -> String {
        var sanitized = text
        while let last = sanitized.last, last == "\r" || last == "\n" {
            sanitized.removeLast()
        }
        return sanitized
    }

    private func appendFlattenedHardBreak(from segment: PreparedSegment, into attributedText: NSMutableAttributedString) {
        let shouldAppendSpacer = attributedText.length == 0 || !attributedText.string.hasSuffix(" ")
        guard shouldAppendSpacer else {
            return
        }

        let spacer = NSAttributedString(
            string: " ",
            attributes: segment.attributedText.length > 0
                ? segment.attributedText.attributes(at: 0, effectiveRange: nil)
                : [:]
        )
        attributedText.append(spacer)
    }

    private func fontLineHeight(from attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        if let ctFont = ctFont(from: attributes[kCTFontAttributeName as NSAttributedString.Key]) {
            return CGFloat(CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont) + CTFontGetLeading(ctFont))
        }

        #if canImport(UIKit)
        if let font = attributes[.font] as? UIFont {
            return font.lineHeight
        }
        #elseif canImport(AppKit)
        if let font = attributes[.font] as? NSFont {
            return font.ascender - font.descender + font.leading
        }
        #endif

        let defaultFont = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
        return CGFloat(CTFontGetAscent(defaultFont) + CTFontGetDescent(defaultFont) + CTFontGetLeading(defaultFont))
    }

    private func ctFont(from value: Any?) -> CTFont? {
        guard let value else {
            return nil
        }
        let object = value as AnyObject
        guard CFGetTypeID(object) == CTFontGetTypeID() else {
            return nil
        }
        return unsafeDowncast(object, to: CTFont.self)
    }

    private func preferredNativeLineBreaking(for source: String) -> Bool {
        var hasRTLScript = false
        var hasCJKScript = false
        var hasEmoji = false
        var hasLatinOrDigits = false

        for scalar in source.unicodeScalars {
            switch scalar.value {
            case 0x0590...0x08FF:
                hasRTLScript = true
            case 0x1100...0x11FF, 0x2E80...0x2EFF, 0x2F00...0x2FDF, 0x3000...0x303F,
                 0x3040...0x309F, 0x30A0...0x30FF, 0x31F0...0x31FF, 0x3400...0x4DBF,
                 0x4E00...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF:
                hasCJKScript = true
            case 0x0030...0x0039, 0x0041...0x005A, 0x0061...0x007A:
                hasLatinOrDigits = true
            case 0x1F300...0x1FAFF:
                hasEmoji = true
            default:
                break
            }
        }

        if hasCJKScript || hasEmoji {
            return true
        }

        if hasRTLScript && hasLatinOrDigits {
            return true
        }

        return hasRTLScript
    }

    func shouldUseNativeLineBreaking(
        for prepared: PreparedText,
        strategy: PreparedTextLineBreakStrategy
    ) -> Bool {
        guard prepared.storage.nativeLineBreakingSource != nil,
              prepared.storage.nativeTypesetter != nil else {
            return false
        }

        switch strategy {
        case .automatic:
            return prepared.storage.core.prefersNativeLineBreaking
        case .uikitConservative, .urlFriendly:
            return false
        case .cjkImproved:
            return prepared.storage.core.segments.contains { $0.kind == .cjkRun } || prepared.storage.core.prefersNativeLineBreaking
        case .nativeTypesetterPreferred:
            return true
        }
    }

    private func nativeNextLine(_ prepared: PreparedText, cursor startCursor: LayoutCursor, maxWidth: CGFloat) -> LineResult? {
        let source = prepared.storage.nativeLineBreakingSource ?? prepared.storage.source
        let typesetter = prepared.storage.nativeTypesetter ?? CTTypesetterCreateWithAttributedString(source as CFAttributedString)
        let startOffset = utf16Offset(for: startCursor, in: prepared.storage.core)
        guard startOffset < source.length else {
            return nil
        }

        let visibleLength = CTTypesetterSuggestLineBreak(typesetter, startOffset, Double(max(maxWidth, 0)))
        guard visibleLength > 0 else {
            return nil
        }
        let ctLine = CTTypesetterCreateLine(typesetter, CFRange(location: startOffset, length: visibleLength))

        let visibleStart = startOffset
        let visibleRange = NSRange(location: visibleStart, length: visibleLength)
        let trimmedVisibleLength = trimmedPaintLength(
            in: source,
            visibleRange: visibleRange,
            whiteSpaceMode: prepared.storage.options.whiteSpaceMode
        )
        let absolutePaintEnd = visibleStart + trimmedVisibleLength
        let absoluteVisibleEnd = visibleStart + visibleLength
        let width = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
        let trailingWhitespace = CGFloat(CTLineGetTrailingWhitespaceWidth(ctLine))
        let start = cursor(forUTF16Offset: startOffset, in: prepared.storage.core)
        let paintEnd = cursor(forUTF16Offset: absolutePaintEnd, in: prepared.storage.core)
        let visibleEnd = cursor(forUTF16Offset: absoluteVisibleEnd, in: prepared.storage.core)
        let consumedEnd = consumedNativeBreakCursor(
            after: visibleEnd,
            in: prepared.storage.core,
            whiteSpaceMode: prepared.storage.options.whiteSpaceMode
        )

        guard consumedEnd > start else {
            return nil
        }

        return LineResult(
            width: width,
            paintWidth: max(width - trailingWhitespace, 0),
            start: start,
            end: consumedEnd,
            paintEnd: paintEnd,
            discretionaryHyphenSegmentIndex: nil
        )
    }

    private func trimmedPaintLength(
        in attributedText: NSAttributedString,
        visibleRange: NSRange,
        whiteSpaceMode: WhiteSpaceMode
    ) -> Int {
        guard visibleRange.length > 0, whiteSpaceMode != .preWrap else {
            return visibleRange.length
        }

        var trimmed = attributedText.attributedSubstring(from: visibleRange).string
        while let last = trimmed.last,
              last.isWhitespace,
              last != "\u{00A0}" {
            trimmed.removeLast()
        }

        return trimmed.utf16.count
    }

    private func utf16Offset(for cursor: LayoutCursor, in core: PreparedTextCore) -> Int {
        var offset = 0
        for index in 0..<min(cursor.segmentIndex, core.segments.count) {
            offset += core.segments[index].string.utf16.count
        }

        guard core.segments.indices.contains(cursor.segmentIndex) else {
            return offset
        }

        let segment = core.segments[cursor.segmentIndex]
        return offset + segment.graphemeUTF16Offsets[min(cursor.graphemeIndex, segment.graphemeUTF16Offsets.count - 1)]
    }

    private func cursor(forUTF16Offset utf16Offset: Int, in core: PreparedTextCore) -> LayoutCursor {
        var remaining = max(utf16Offset, 0)

        for (segmentIndex, segment) in core.segments.enumerated() {
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

        return LayoutCursor(segmentIndex: core.segments.count, graphemeIndex: 0)
    }

    private func consumedNativeBreakCursor(
        after cursor: LayoutCursor,
        in core: PreparedTextCore,
        whiteSpaceMode: WhiteSpaceMode
    ) -> LayoutCursor {
        guard whiteSpaceMode != .preWrap else {
            return cursor
        }

        var consumed = cursor
        while consumed.segmentIndex < core.segments.count, consumed.graphemeIndex == 0 {
            switch core.segments[consumed.segmentIndex].kind {
            case .whitespace, .tab, .zeroWidthBreak, .softHyphen:
                consumed.segmentIndex += 1
            case .hardBreak:
                consumed.segmentIndex += 1
                return consumed
            default:
                return consumed
            }
        }

        return consumed
    }

    private func nativeLineBreakingSource(
        from source: NSAttributedString,
        tabStopAdvance: CGFloat,
        preservesSourceCoordinateSpace: Bool
    ) -> NSAttributedString? {
        guard preservesSourceCoordinateSpace else {
            return nil
        }

        guard source.string.contains("\t") else {
            return source
        }

        let mutable = NSMutableAttributedString(attributedString: source)
        applyTabLayoutAttributes(to: mutable, tabStopAdvance: tabStopAdvance)
        return mutable.copy() as? NSAttributedString ?? mutable
    }

    private func applyTabLayoutAttributes(to attributedText: NSMutableAttributedString, tabStopAdvance: CGFloat) {
        let fullRange = NSRange(location: 0, length: attributedText.length)
        guard fullRange.length > 0 else {
            return
        }

        attributedText.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
            let paragraphStyle = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            paragraphStyle.defaultTabInterval = tabStopAdvance
            paragraphStyle.tabStops = []
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
    }

    private func recordObservedLayout(_ lineCount: Int) {
        observedLayoutCount += 1
        observedLayoutLineCount += lineCount
    }

    private func resolvedAttachmentSource(
        from attributedText: NSAttributedString,
        sourceID: PreparedTextSourceID?
    ) -> NSAttributedString {
        guard attributedText.length > 0 else {
            return attributedText.copy() as? NSAttributedString ?? NSAttributedString(attributedString: attributedText)
        }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        var touched = false
        var referencedAttachmentIDs: Set<PreparedAttachmentID> = []

        mutable.enumerateAttributes(in: NSRange(location: 0, length: mutable.length), options: []) { attributes, range, _ in
            guard let attachment = attributes[.attachment] as? NSTextAttachment else {
                return
            }

            let reference = (attributes[.preparedAttachmentReference] as? PreparedAttachmentReference)
                ?? (attachment as? PreparedTextAttachment)?.reference
            guard let reference else {
                return
            }

            referencedAttachmentIDs.insert(reference.id)
            let resolvedAttachment = attachmentResolver?.resolvedAttachment(for: reference)
            let resolvedBounds = resolvedAttachment?.bounds ?? reference.placeholderBounds
            let replacement = clonedAttachment(from: attachment, reference: reference, bounds: resolvedBounds)

            mutable.removeAttribute(.attachment, range: range)
            mutable.addAttribute(.attachment, value: replacement, range: range)
            mutable.addAttribute(.preparedAttachmentReference, value: reference, range: range)

            if let contentIdentity = resolvedAttachment?.contentIdentity {
                mutable.addAttribute(.preparedResolvedAttachmentIdentity, value: contentIdentity, range: range)
            } else {
                mutable.removeAttribute(.preparedResolvedAttachmentIdentity, range: range)
            }

            touched = true
        }

        if let registry = attachmentResolver as? PreparedAttachmentRegistry {
            registry.recordUsage(of: referencedAttachmentIDs, sourceID: sourceID)
        }

        if touched {
            return mutable.copy() as? NSAttributedString ?? mutable
        }

        return attributedText.copy() as? NSAttributedString ?? NSAttributedString(attributedString: attributedText)
    }

    private func clonedAttachment(
        from attachment: NSTextAttachment,
        reference: PreparedAttachmentReference,
        bounds: CGRect
    ) -> NSTextAttachment {
        let cloned: NSTextAttachment
        if attachment is PreparedTextAttachment {
            cloned = PreparedTextAttachment(reference: reference)
        } else {
            cloned = NSTextAttachment(data: nil, ofType: nil)
        }

        cloned.bounds = bounds
        cloned.fileWrapper = attachment.fileWrapper
        cloned.image = attachment.image
        return cloned
    }
}

private func cursorAdvancingFromTextSegment(segmentIndex: Int, endIndex: Int, graphemeCount: Int) -> LayoutCursor {
    if endIndex >= graphemeCount {
        return LayoutCursor(segmentIndex: segmentIndex + 1, graphemeIndex: 0)
    }
    return LayoutCursor(segmentIndex: segmentIndex, graphemeIndex: endIndex)
}

final class SegmentMeasurementCache {
    struct Metrics {
        var width: CGFloat
        var trailingWhitespaceWidth: CGFloat
        var graphemeAdvances: [CGFloat]
        var graphemePrefixAdvances: [CGFloat]
        var graphemeUTF16Offsets: [Int]
    }

    private let cache = CostBoundCache<SegmentMeasurementKey, Metrics>(
        countLimit: 2_048,
        totalCostLimit: 8 * 1_024 * 1_024,
        cost: { metrics in
            max(metrics.graphemeAdvances.count + metrics.graphemePrefixAdvances.count + metrics.graphemeUTF16Offsets.count, 1) * MemoryLayout<CGFloat>.size
        }
    )

    func metric(for key: SegmentMeasurementKey) -> Metrics? {
        cache.value(forKey: key)
    }

    func insert(_ metrics: Metrics, for key: SegmentMeasurementKey) {
        cache.insert(metrics, forKey: key)
    }

    func invalidateAll() {
        cache.removeAll()
    }

    func invalidate(sourceIDs: Set<PreparedTextSourceID>) {
        cache.removeAll { key, _ in
            guard let sourceID = key.identity.sourceID else {
                return false
            }
            return sourceIDs.contains(sourceID)
        }
    }

    func trimForBackground() {
        let snapshot = cache.snapshot
        cache.trim(
            countLimit: snapshot.countLimit.map { max($0 / 2, 1) },
            totalCostLimit: snapshot.totalCostLimit.map { max($0 / 2, 1) }
        )
    }

    var snapshot: CacheDiagnosticsSnapshot {
        cache.snapshot
    }
}
