import CoreGraphics
import CoreText
import Foundation

struct TextLineWalker {
    struct BreakCandidate {
        var end: LayoutCursor
        var paintEnd: LayoutCursor
        var width: CGFloat
        var paintWidth: CGFloat
        var discretionaryHyphenSegmentIndex: Int?
    }

    let core: PreparedTextCore
    let options: PreparedTextOptions

    func nextLine(from startCursor: LayoutCursor, maxWidth: CGFloat) -> LineResult? {
        guard !core.segments.isEmpty else {
            return nil
        }

        let start = normalizedLineStart(from: startCursor)
        guard start.segmentIndex < core.segments.count else {
            return nil
        }

        var current = start
        var runningWidth: CGFloat = 0
        var terminalEnd = start
        var terminalPaintEnd = start
        var terminalWidth: CGFloat = 0
        var terminalPaintWidth: CGFloat = 0
        var lastExternalBreak: BreakCandidate?
        var lastInternalBreak: BreakCandidate?

        while current.segmentIndex < core.segments.count {
            let segmentIndex = current.segmentIndex
            let segment = core.segments[segmentIndex]

            if segment.kind == .hardBreak, current.graphemeIndex == 0 {
                let consumed = LayoutCursor(segmentIndex: segmentIndex + 1, graphemeIndex: 0)
                return LineResult(
                    width: terminalWidth,
                    paintWidth: terminalPaintWidth,
                    start: start,
                    end: consumed,
                    paintEnd: terminalPaintEnd,
                    discretionaryHyphenSegmentIndex: nil
                )
            }

            let positionBefore = runningWidth

            switch segment.kind {
            case .softHyphen:
                let consumed = LayoutCursor(segmentIndex: segmentIndex + 1, graphemeIndex: 0)
                terminalEnd = consumed
                terminalPaintEnd = current
                terminalWidth = positionBefore
                terminalPaintWidth = positionBefore

                let hyphenWidth = positionBefore + segment.discretionaryHyphenAdvance
                if hyphenWidth <= maxWidth + 0.5 {
                    lastInternalBreak = BreakCandidate(
                        end: consumed,
                        paintEnd: current,
                        width: hyphenWidth,
                        paintWidth: hyphenWidth,
                        discretionaryHyphenSegmentIndex: segmentIndex
                    )
                }

                current = consumed

            case .zeroWidthBreak:
                let consumed = LayoutCursor(segmentIndex: segmentIndex + 1, graphemeIndex: 0)
                terminalEnd = consumed
                terminalPaintEnd = current
                terminalWidth = positionBefore
                terminalPaintWidth = positionBefore
                lastExternalBreak = BreakCandidate(
                    end: consumed,
                    paintEnd: current,
                    width: positionBefore,
                    paintWidth: positionBefore,
                    discretionaryHyphenSegmentIndex: nil
                )
                current = consumed

            case .tab:
                let continueAdvance = advance(for: segment, positionBefore: positionBefore)
                let consumed = LayoutCursor(segmentIndex: segmentIndex + 1, graphemeIndex: 0)

                if positionBefore + continueAdvance <= maxWidth || positionBefore == 0 {
                    runningWidth += continueAdvance
                    terminalEnd = consumed
                    terminalPaintEnd = consumed
                    terminalWidth = positionBefore + continueAdvance
                    terminalPaintWidth = positionBefore + continueAdvance
                    lastExternalBreak = BreakCandidate(
                        end: consumed,
                        paintEnd: consumed,
                        width: terminalWidth,
                        paintWidth: terminalPaintWidth,
                        discretionaryHyphenSegmentIndex: nil
                    )
                    current = consumed
                    continue
                }

                if let priorBreak = preferredPriorBreak(
                    from: start,
                    external: lastExternalBreak,
                    internalBreak: lastInternalBreak
                ) {
                    return line(from: start, using: priorBreak)
                }

                if start == current {
                    return LineResult(
                        width: positionBefore + continueAdvance,
                        paintWidth: positionBefore + continueAdvance,
                        start: start,
                        end: consumed,
                        paintEnd: consumed,
                        discretionaryHyphenSegmentIndex: nil
                    )
                }

                return LineResult(
                    width: terminalWidth,
                    paintWidth: terminalPaintWidth,
                    start: start,
                    end: current,
                    paintEnd: terminalPaintEnd,
                    discretionaryHyphenSegmentIndex: nil
                )

            case .word, .urlLike, .cjkRun, .punctuationPrefix, .punctuationSuffix, .glue, .whitespace:
                let remainingAdvance = segment.remainingAdvance(from: current.graphemeIndex)
                let consumed = cursor(afterConsumingTextSegmentAt: segmentIndex, startingAt: current.graphemeIndex)

                if positionBefore + remainingAdvance <= maxWidth {
                    runningWidth += remainingAdvance
                    let fitAdvance = lineEndFitAdvance(for: segment, positionBefore: positionBefore)
                    let paintAdvance = lineEndPaintAdvance(for: segment, positionBefore: positionBefore)
                    terminalEnd = consumed
                    terminalPaintEnd = paintAdvance < fitAdvance ? current : consumed
                    terminalWidth = positionBefore + fitAdvance
                    terminalPaintWidth = positionBefore + paintAdvance
                    if let nextKind = nextSegmentKind(after: segmentIndex), isBreakOpportunityAfterText(nextKind) {
                        lastExternalBreak = BreakCandidate(
                            end: consumedBreakCursor(after: consumed),
                            paintEnd: terminalPaintEnd,
                            width: terminalWidth,
                            paintWidth: terminalPaintWidth,
                            discretionaryHyphenSegmentIndex: nil
                        )
                    }
                    current = consumed
                    continue
                }

                // Structured URL/social-token delimiter splits are only preferred when
                // the token itself starts the line and would otherwise fall straight to
                // generic internal wrapping.
                if shouldUseStructuredTokenSplitBeforeBreak(
                    for: segment,
                    startGraphemeIndex: current.graphemeIndex,
                    positionBefore: positionBefore,
                    remainingAdvance: remainingAdvance,
                    maxWidth: maxWidth
                ), let splitCursor = preferredBreakCursor(
                    for: segment,
                    segmentIndex: segmentIndex,
                    startGraphemeIndex: current.graphemeIndex,
                    availableWidth: maxWidth - positionBefore
                ) {
                    let consumedWidth = segment.advance(from: current.graphemeIndex, to: splitCursor.graphemeIndex)
                    let width = positionBefore + consumedWidth
                    return LineResult(
                        width: width,
                        paintWidth: width,
                        start: start,
                        end: splitCursor,
                        paintEnd: splitCursor,
                        discretionaryHyphenSegmentIndex: nil
                    )
                }

                if let preferredInternalBreak = preferredInternalBreakBeforePriorBreak(
                    for: segment,
                    segmentIndex: segmentIndex,
                    lineStart: start,
                    startGraphemeIndex: current.graphemeIndex,
                    positionBefore: positionBefore,
                    maxWidth: maxWidth,
                    priorBreak: preferredPriorBreak(
                        from: start,
                        external: lastExternalBreak,
                        internalBreak: lastInternalBreak
                    )
                ) {
                    return line(from: start, using: preferredInternalBreak)
                }

                if let priorBreak = preferredPriorBreak(
                    from: start,
                    external: lastExternalBreak,
                    internalBreak: lastInternalBreak
                ) {
                    return line(from: start, using: priorBreak)
                }

                let available = availableWidthReservingTrailingPunctuation(
                    after: segmentIndex,
                    baseAvailableWidth: maxWidth - positionBefore
                )
                if segment.allowsInternalWrapping,
                   let splitCursor = internalWrapCursor(
                       for: segment,
                       segmentIndex: segmentIndex,
                       startGraphemeIndex: current.graphemeIndex,
                       availableWidth: available
                   ) {
                    let consumedWidth = segment.advance(from: current.graphemeIndex, to: splitCursor.graphemeIndex)
                    let width = positionBefore + consumedWidth
                    return LineResult(
                        width: width,
                        paintWidth: width,
                        start: start,
                        end: splitCursor,
                        paintEnd: splitCursor,
                        discretionaryHyphenSegmentIndex: nil
                    )
                }

                if start == current {
                    if segment.allowsInternalWrapping {
                        let forced = forcedSplitCursor(
                            for: segment,
                            segmentIndex: segmentIndex,
                            startGraphemeIndex: current.graphemeIndex
                        )
                        let consumedWidth = segment.advance(from: current.graphemeIndex, to: forced.graphemeIndex)
                        let width = positionBefore + consumedWidth
                        return LineResult(
                            width: width,
                            paintWidth: width,
                            start: start,
                            end: forced,
                            paintEnd: forced,
                            discretionaryHyphenSegmentIndex: nil
                        )
                    }

                    return LineResult(
                        width: positionBefore + remainingAdvance,
                        paintWidth: positionBefore + remainingAdvance,
                        start: start,
                        end: consumed,
                        paintEnd: consumed,
                        discretionaryHyphenSegmentIndex: nil
                    )
                }

                return LineResult(
                    width: terminalWidth,
                    paintWidth: terminalPaintWidth,
                    start: start,
                    end: current,
                    paintEnd: terminalPaintEnd,
                    discretionaryHyphenSegmentIndex: nil
                )

            case .hardBreak:
                break
            }
        }

        guard terminalEnd > start || start.segmentIndex < core.segments.count else {
            return nil
        }

        return LineResult(
            width: terminalWidth,
            paintWidth: terminalPaintWidth,
            start: start,
            end: terminalEnd,
            paintEnd: terminalPaintEnd,
            discretionaryHyphenSegmentIndex: nil
        )
    }

    private func line(from start: LayoutCursor, using breakCandidate: BreakCandidate) -> LineResult {
        LineResult(
            width: breakCandidate.width,
            paintWidth: breakCandidate.paintWidth,
            start: start,
            end: breakCandidate.end,
            paintEnd: breakCandidate.paintEnd,
            discretionaryHyphenSegmentIndex: breakCandidate.discretionaryHyphenSegmentIndex
        )
    }

    private func preferredPriorBreak(
        from start: LayoutCursor,
        external: BreakCandidate?,
        internalBreak: BreakCandidate?
    ) -> BreakCandidate? {
        if let internalBreak,
           internalBreak.discretionaryHyphenSegmentIndex != nil,
           internalBreak.end > start {
            if let external, external.end > start, external.end > internalBreak.end {
                return external
            }
            return internalBreak
        }

        if let external, external.end > start {
            return external
        }

        guard let internalBreak, internalBreak.end > start else {
            return nil
        }
        return internalBreak
    }

    private func normalizedLineStart(from cursor: LayoutCursor) -> LayoutCursor {
        var normalized = cursor

        while normalized.segmentIndex < core.segments.count, normalized.graphemeIndex == 0 {
            let segment = core.segments[normalized.segmentIndex]
            switch options.whiteSpaceMode {
            case .cssNormal:
                switch segment.kind {
                case .whitespace, .zeroWidthBreak, .softHyphen:
                    normalized.segmentIndex += 1
                default:
                    return normalized
                }
            case .uikitLiteral, .preWrap:
                switch segment.kind {
                case .zeroWidthBreak, .softHyphen:
                    normalized.segmentIndex += 1
                default:
                    return normalized
                }
            }
        }

        return normalized
    }

    private func preferredBreakCursor(
        for segment: PreparedSegment,
        segmentIndex: Int,
        startGraphemeIndex: Int,
        availableWidth: CGFloat
    ) -> LayoutCursor? {
        guard !segment.preferredBreakGraphemeIndices.isEmpty else {
            return nil
        }

        let baseWidth = segment.prefixWidth(at: startGraphemeIndex)
        let characters = Array(segment.string)
        var bestQueryIndex: Int?
        var bestStrongIndex: Int?
        var bestWeakIndex: Int?

        for index in segment.preferredBreakGraphemeIndices where index > startGraphemeIndex {
            let candidateWidth = segment.prefixWidth(at: index) - baseWidth
            if candidateWidth <= availableWidth + 0.5 {
                switch delimiterBreakPriority(in: characters, breakIndex: index) {
                case .query:
                    bestQueryIndex = bestQueryIndex ?? index
                case .weak:
                    bestWeakIndex = index
                case .strong:
                    bestStrongIndex = index
                }
            } else {
                break
            }
        }

        if let bestQueryIndex {
            return cursor(for: segmentIndex, graphemeIndex: bestQueryIndex, graphemeCount: segment.graphemeCount)
        }

        if let bestStrongIndex {
            return cursor(for: segmentIndex, graphemeIndex: bestStrongIndex, graphemeCount: segment.graphemeCount)
        }

        guard let bestWeakIndex else {
            return nil
        }

        let candidateWidth = segment.prefixWidth(at: bestWeakIndex) - baseWidth
        let fillRatio = availableWidth > 0 ? candidateWidth / availableWidth : 1
        guard fillRatio >= 0.85 else {
            return nil
        }

        return cursor(for: segmentIndex, graphemeIndex: bestWeakIndex, graphemeCount: segment.graphemeCount)
    }

    private func graphemeSplitCursor(
        for segment: PreparedSegment,
        segmentIndex: Int,
        startGraphemeIndex: Int,
        availableWidth: CGFloat
    ) -> LayoutCursor? {
        guard segment.graphemeCount > startGraphemeIndex else {
            return nil
        }

        let baseWidth = segment.prefixWidth(at: startGraphemeIndex)
        var bestIndex = startGraphemeIndex

        for index in (startGraphemeIndex + 1)...segment.graphemeCount {
            let candidateWidth = segment.prefixWidth(at: index) - baseWidth
            if candidateWidth <= availableWidth + 0.5 {
                bestIndex = index
            } else {
                break
            }
        }

        guard bestIndex > startGraphemeIndex else {
            return nil
        }

        return cursor(for: segmentIndex, graphemeIndex: bestIndex, graphemeCount: segment.graphemeCount)
    }

    private func forcedSplitCursor(
        for segment: PreparedSegment,
        segmentIndex: Int,
        startGraphemeIndex: Int
    ) -> LayoutCursor {
        let nextIndex = min(startGraphemeIndex + 1, segment.graphemeCount)
        return cursor(for: segmentIndex, graphemeIndex: nextIndex, graphemeCount: segment.graphemeCount)
    }

    private func delimiterBreakPriority(in characters: [Character], breakIndex: Int) -> DelimiterBreakPriority {
        guard breakIndex > 0, breakIndex - 1 < characters.count else {
            return .strong
        }
        switch characters[breakIndex - 1] {
        case ".":
            return .weak
        case "?", "&":
            return .query
        default:
            return .strong
        }
    }

    private func advance(for segment: PreparedSegment, positionBefore: CGFloat) -> CGFloat {
        switch segment.kind {
        case .tab:
            let tabStop = max(core.tabStopAdvance, 1)
            let stopIndex = floor(positionBefore / tabStop)
            let nextStop = (stopIndex + 1) * tabStop
            let delta = nextStop - positionBefore
            return max(delta, CGFloat.leastNonzeroMagnitude)
        default:
            return segment.continueAdvance
        }
    }

    private func shouldUseStructuredTokenSplitBeforeBreak(
        for segment: PreparedSegment,
        startGraphemeIndex: Int,
        positionBefore: CGFloat,
        remainingAdvance: CGFloat,
        maxWidth: CGFloat
    ) -> Bool {
        segment.kind == .urlLike &&
            startGraphemeIndex == 0 &&
            positionBefore == 0 &&
            remainingAdvance > maxWidth + 0.5 &&
            !segment.preferredBreakGraphemeIndices.isEmpty
    }

    private func internalWrapCursor(
        for segment: PreparedSegment,
        segmentIndex: Int,
        startGraphemeIndex: Int,
        availableWidth: CGFloat
    ) -> LayoutCursor? {
        if segment.kind == .cjkRun {
            return clusterBreakCursor(
                for: segment,
                segmentIndex: segmentIndex,
                startGraphemeIndex: startGraphemeIndex,
                availableWidth: availableWidth
            ) ?? graphemeSplitCursor(
                for: segment,
                segmentIndex: segmentIndex,
                startGraphemeIndex: startGraphemeIndex,
                availableWidth: availableWidth
            )
        }

        if segment.kind == .urlLike {
            return preferredBreakCursor(
                for: segment,
                segmentIndex: segmentIndex,
                startGraphemeIndex: startGraphemeIndex,
                availableWidth: availableWidth
            ) ?? graphemeSplitCursor(
                for: segment,
                segmentIndex: segmentIndex,
                startGraphemeIndex: startGraphemeIndex,
                availableWidth: availableWidth
            )
        }

        if segment.kind == .word,
           shouldPreferTypesetterWordWrap(for: segment) {
            return typesetterLineBreakCursor(
                for: segment,
                segmentIndex: segmentIndex,
                startGraphemeIndex: startGraphemeIndex,
                availableWidth: availableWidth
            ) ?? graphemeSplitCursor(
                for: segment,
                segmentIndex: segmentIndex,
                startGraphemeIndex: startGraphemeIndex,
                availableWidth: availableWidth
            )
        }

        return graphemeSplitCursor(
            for: segment,
            segmentIndex: segmentIndex,
            startGraphemeIndex: startGraphemeIndex,
            availableWidth: availableWidth
        )
    }

    private func shouldPreferTypesetterWordWrap(for segment: PreparedSegment) -> Bool {
        segment.string.contains("-") || segment.string.contains("_")
    }

    private func typesetterLineBreakCursor(
        for segment: PreparedSegment,
        segmentIndex: Int,
        startGraphemeIndex: Int,
        availableWidth: CGFloat
    ) -> LayoutCursor? {
        guard startGraphemeIndex < segment.graphemeCount, availableWidth > 0 else {
            return nil
        }

        let attributedSlice = segment.slice(from: startGraphemeIndex, to: segment.graphemeCount)
        let typesetter = CTTypesetterCreateWithAttributedString(attributedSlice as CFAttributedString)
        let suggestedLength = CTTypesetterSuggestLineBreak(typesetter, 0, Double(availableWidth))
        guard suggestedLength > 0 else {
            return nil
        }

        let baseOffset = segment.graphemeUTF16Offsets[startGraphemeIndex]
        var bestIndex = startGraphemeIndex
        for index in (startGraphemeIndex + 1)...segment.graphemeCount {
            let relativeOffset = segment.graphemeUTF16Offsets[index] - baseOffset
            if relativeOffset <= suggestedLength {
                bestIndex = index
            } else {
                break
            }
        }

        guard bestIndex > startGraphemeIndex else {
            return nil
        }

        return cursor(for: segmentIndex, graphemeIndex: bestIndex, graphemeCount: segment.graphemeCount)
    }

    private func clusterBreakCursor(
        for segment: PreparedSegment,
        segmentIndex: Int,
        startGraphemeIndex: Int,
        availableWidth: CGFloat
    ) -> LayoutCursor? {
        guard startGraphemeIndex < segment.graphemeCount, availableWidth > 0 else {
            return nil
        }

        let attributedSlice = segment.slice(from: startGraphemeIndex, to: segment.graphemeCount)
        let typesetter = CTTypesetterCreateWithAttributedString(attributedSlice as CFAttributedString)
        let suggestedLength = CTTypesetterSuggestClusterBreak(typesetter, 0, Double(availableWidth))
        guard suggestedLength > 0 else {
            return nil
        }

        let baseOffset = segment.graphemeUTF16Offsets[startGraphemeIndex]
        var bestIndex = startGraphemeIndex
        for index in (startGraphemeIndex + 1)...segment.graphemeCount {
            let relativeOffset = segment.graphemeUTF16Offsets[index] - baseOffset
            if relativeOffset <= suggestedLength {
                bestIndex = index
            } else {
                break
            }
        }

        guard bestIndex > startGraphemeIndex else {
            return nil
        }

        return cursor(for: segmentIndex, graphemeIndex: bestIndex, graphemeCount: segment.graphemeCount)
    }

    private func lineEndFitAdvance(for segment: PreparedSegment, positionBefore: CGFloat) -> CGFloat {
        switch segment.kind {
        case .tab:
            return advance(for: segment, positionBefore: positionBefore)
        default:
            return segment.lineEndFitAdvance
        }
    }

    private func lineEndPaintAdvance(for segment: PreparedSegment, positionBefore: CGFloat) -> CGFloat {
        switch segment.kind {
        case .tab:
            return advance(for: segment, positionBefore: positionBefore)
        default:
            return segment.lineEndPaintAdvance
        }
    }

    private func preferredInternalBreakBeforePriorBreak(
        for segment: PreparedSegment,
        segmentIndex: Int,
        lineStart: LayoutCursor,
        startGraphemeIndex: Int,
        positionBefore: CGFloat,
        maxWidth: CGFloat,
        priorBreak: BreakCandidate?
    ) -> BreakCandidate? {
        guard segment.kind == .cjkRun,
              startGraphemeIndex == 0,
              segment.graphemeCount - startGraphemeIndex >= 3,
              positionBefore > 0,
              let priorBreak,
              priorBreak.end > lineStart,
              let splitCursor = internalWrapCursor(
                  for: segment,
                  segmentIndex: segmentIndex,
                  startGraphemeIndex: startGraphemeIndex,
                  availableWidth: availableWidthReservingTrailingPunctuation(
                      after: segmentIndex,
                      baseAvailableWidth: maxWidth - positionBefore
                  )
              ) else {
            return nil
        }

        let consumedWidth = segment.advance(from: startGraphemeIndex, to: splitCursor.graphemeIndex)
        let width = positionBefore + consumedWidth
        let minimumImprovement = max(4, maxWidth * 0.08)
        guard width > priorBreak.width + minimumImprovement else {
            return nil
        }

        return BreakCandidate(
            end: splitCursor,
            paintEnd: splitCursor,
            width: width,
            paintWidth: width,
            discretionaryHyphenSegmentIndex: nil
        )
    }

    private func availableWidthReservingTrailingPunctuation(
        after segmentIndex: Int,
        baseAvailableWidth: CGFloat
    ) -> CGFloat {
        guard let nextKind = nextSegmentKind(after: segmentIndex),
              nextKind == .punctuationSuffix,
              core.segments.indices.contains(segmentIndex + 1) else {
            return baseAvailableWidth
        }

        let punctuationWidth = core.segments[segmentIndex + 1].continueAdvance
        let reserved = baseAvailableWidth - punctuationWidth
        return reserved > 0 ? reserved : baseAvailableWidth
    }

    private func cursor(for segmentIndex: Int, graphemeIndex: Int, graphemeCount: Int) -> LayoutCursor {
        if graphemeIndex >= graphemeCount {
            return LayoutCursor(segmentIndex: segmentIndex + 1, graphemeIndex: 0)
        }
        return LayoutCursor(segmentIndex: segmentIndex, graphemeIndex: graphemeIndex)
    }

    private func cursor(afterConsumingTextSegmentAt segmentIndex: Int, startingAt _: Int) -> LayoutCursor {
        LayoutCursor(segmentIndex: segmentIndex + 1, graphemeIndex: 0)
    }

    private func nextSegmentKind(after segmentIndex: Int) -> SegmentKind? {
        let nextIndex = segmentIndex + 1
        guard core.segments.indices.contains(nextIndex) else {
            return nil
        }
        return core.segments[nextIndex].kind
    }

    private func consumedBreakCursor(after cursor: LayoutCursor) -> LayoutCursor {
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

    private func isBreakOpportunityAfterText(_ kind: SegmentKind) -> Bool {
        switch kind {
        case .whitespace, .tab, .zeroWidthBreak, .hardBreak:
            return true
        default:
            return false
        }
    }
}

extension PreparedSegment {
    func prefixWidth(at graphemeIndex: Int) -> CGFloat {
        graphemePrefixAdvances[min(max(graphemeIndex, 0), graphemePrefixAdvances.count - 1)]
    }

    func remainingAdvance(from graphemeIndex: Int) -> CGFloat {
        continueAdvance - prefixWidth(at: graphemeIndex)
    }

    func advance(from start: Int, to end: Int) -> CGFloat {
        prefixWidth(at: end) - prefixWidth(at: start)
    }

    func slice(from start: Int, to end: Int) -> NSAttributedString {
        let startOffset = graphemeUTF16Offsets[start]
        let endOffset = graphemeUTF16Offsets[end]
        return attributedText.attributedSubstring(
            from: NSRange(location: startOffset, length: endOffset - startOffset)
        )
    }
}

private enum DelimiterBreakPriority {
    case query
    case strong
    case weak
}
