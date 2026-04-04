import CoreText
import Foundation
import NaturalLanguage

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct TextSegmenter {
    let options: PreparedTextOptions
    let segmentMeasurementCache: SegmentMeasurementCache

    func segment(_ attributedText: NSAttributedString) -> [PreparedSegment] {
        guard attributedText.length > 0 else {
            return []
        }

        let normalizedAttributedText = normalizedLineBreaks(in: attributedText)
        var segments: [PreparedSegment] = []
        var pendingCollapsedWhitespaceAttributes: [NSAttributedString.Key: Any]?
        var hasVisibleContent = false

        normalizedAttributedText.enumerateAttributes(in: NSRange(location: 0, length: normalizedAttributedText.length), options: []) { attributes, range, _ in
            let raw = normalizedAttributedText.attributedSubstring(from: range).string
            var visibleBuffer = ""
            var whitespaceBuffer = ""

            func flushVisibleBuffer() {
                guard !visibleBuffer.isEmpty else {
                    return
                }
                if let pendingAttributes = pendingCollapsedWhitespaceAttributes {
                    segments.append(makeWhitespaceSegment(text: " ", attributes: pendingAttributes))
                    pendingCollapsedWhitespaceAttributes = nil
                    hasVisibleContent = true
                }
                appendVisibleTokenSegments(visibleBuffer, attributes: attributes, segments: &segments)
                visibleBuffer.removeAll(keepingCapacity: true)
                hasVisibleContent = true
            }

            func flushWhitespaceBuffer() {
                guard !whitespaceBuffer.isEmpty else {
                    return
                }
                segments.append(makeWhitespaceSegment(text: whitespaceBuffer, attributes: attributes))
                whitespaceBuffer.removeAll(keepingCapacity: true)
                hasVisibleContent = true
            }

            for character in raw {
                switch options.whiteSpaceMode {
                case .cssNormal:
                    switch character {
                    case "\u{200B}":
                        flushVisibleBuffer()
                        segments.append(makeSegment(kind: .zeroWidthBreak, text: String(character), attributes: attributes))
                    case "\u{00AD}":
                        flushVisibleBuffer()
                        segments.append(makeSegment(kind: .softHyphen, text: String(character), attributes: attributes))
                    case "\u{00A0}":
                        if let pendingAttributes = pendingCollapsedWhitespaceAttributes {
                            segments.append(makeWhitespaceSegment(text: " ", attributes: pendingAttributes))
                            pendingCollapsedWhitespaceAttributes = nil
                            hasVisibleContent = true
                        }
                        visibleBuffer.append(character)
                        hasVisibleContent = true
                    default:
                        if shouldCollapseWhitespace(character) {
                            flushVisibleBuffer()
                            if hasVisibleContent {
                                pendingCollapsedWhitespaceAttributes = pendingCollapsedWhitespaceAttributes ?? attributes
                            }
                        } else {
                            if let pendingAttributes = pendingCollapsedWhitespaceAttributes {
                                segments.append(makeWhitespaceSegment(text: " ", attributes: pendingAttributes))
                                pendingCollapsedWhitespaceAttributes = nil
                                hasVisibleContent = true
                            }
                            visibleBuffer.append(character)
                        }
                    }

                case .uikitLiteral, .preWrap:
                    switch character {
                    case "\u{200B}":
                        flushVisibleBuffer()
                        flushWhitespaceBuffer()
                        segments.append(makeSegment(kind: .zeroWidthBreak, text: String(character), attributes: attributes))
                    case "\u{00AD}":
                        flushVisibleBuffer()
                        flushWhitespaceBuffer()
                        segments.append(makeSegment(kind: .softHyphen, text: String(character), attributes: attributes))
                    case "\n":
                        flushVisibleBuffer()
                        flushWhitespaceBuffer()
                        segments.append(makeSegment(kind: .hardBreak, text: String(character), attributes: attributes))
                        hasVisibleContent = true
                    case "\t":
                        flushVisibleBuffer()
                        flushWhitespaceBuffer()
                        segments.append(makeSegment(kind: .tab, text: String(character), attributes: attributes))
                        hasVisibleContent = true
                    case "\u{00A0}":
                        flushWhitespaceBuffer()
                        visibleBuffer.append(character)
                        hasVisibleContent = true
                    default:
                        if isPreservedWhitespace(character) {
                            flushVisibleBuffer()
                            whitespaceBuffer.append(character)
                        } else {
                            flushWhitespaceBuffer()
                            visibleBuffer.append(character)
                        }
                    }
                }
            }

            flushVisibleBuffer()
            flushWhitespaceBuffer()
        }

        return segments
    }

    func defaultLineHeight(for attributedText: NSAttributedString) -> CGFloat {
        var lineHeight: CGFloat = 0

        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: []) { attributes, _, _ in
            lineHeight = max(lineHeight, self.lineHeight(for: attributes))
        }

        return lineHeight > 0 ? lineHeight : 17
    }

    func preservesSourceCoordinateSpace(for attributedText: NSAttributedString) -> Bool {
        switch options.whiteSpaceMode {
        case .cssNormal:
            return false
        case .uikitLiteral, .preWrap:
            return normalizedLineBreaks(in: attributedText).string == attributedText.string
        }
    }

    func tabStopAdvance(for attributedText: NSAttributedString) -> CGFloat {
        let attributes = attributedText.length > 0 ? attributedText.attributes(at: 0, effectiveRange: nil) : [:]
        let space = makeSegment(kind: .word, text: " ", attributes: attributes)
        let base = max(space.continueAdvance, 4)
        return base * 8
    }

    private func appendVisibleTokenSegments(
        _ rawToken: String,
        attributes: [NSAttributedString.Key: Any],
        segments: inout [PreparedSegment]
    ) {
        guard !rawToken.isEmpty else {
            return
        }

        let standaloneKind = classifyStandaloneToken(rawToken)
        if standaloneKind == .urlLike || standaloneKind == .glue {
            segments.append(makeSegment(kind: standaloneKind, text: rawToken, attributes: attributes))
            return
        }

        if isConnectorWordToken(rawToken) {
            segments.append(makeSegment(kind: .word, text: rawToken, attributes: attributes))
            return
        }

        if rawToken.unicodeScalars.allSatisfy(isCJKScalar) {
            segments.append(makeSegment(kind: .cjkRun, text: rawToken, attributes: attributes))
            return
        }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = rawToken
        if let language = tokenizerLanguage() {
            tokenizer.setLanguage(language)
        }

        let segmentCountBeforeToken = segments.count
        var emittedAnyWord = false
        var previousUpperBound = rawToken.startIndex

        tokenizer.enumerateTokens(in: rawToken.startIndex..<rawToken.endIndex) { range, _ in
            if previousUpperBound < range.lowerBound {
                appendPunctuationSegments(
                    String(rawToken[previousUpperBound..<range.lowerBound]),
                    isPrefixContext: !emittedAnyWord,
                    attributes: attributes,
                    segments: &segments
                )
            }

            let token = String(rawToken[range])
            let kind = classifyStandaloneToken(token)
            segments.append(makeSegment(kind: kind, text: token, attributes: attributes))
            emittedAnyWord = true
            previousUpperBound = range.upperBound
            return true
        }

        if previousUpperBound < rawToken.endIndex {
            appendPunctuationSegments(
                String(rawToken[previousUpperBound..<rawToken.endIndex]),
                isPrefixContext: !emittedAnyWord,
                attributes: attributes,
                segments: &segments
            )
        }

        if !emittedAnyWord, segments.count == segmentCountBeforeToken {
            appendFallbackSegments(rawToken, attributes: attributes, segments: &segments)
        }
    }

    private func appendFallbackSegments(
        _ rawToken: String,
        attributes: [NSAttributedString.Key: Any],
        segments: inout [PreparedSegment]
    ) {
        guard !rawToken.isEmpty else {
            return
        }

        var buffer = ""
        var currentKind: SegmentKind?

        func flush() {
            guard let currentKind, !buffer.isEmpty else {
                return
            }
            segments.append(makeSegment(kind: currentKind, text: buffer, attributes: attributes))
            buffer.removeAll(keepingCapacity: true)
        }

        for scalar in rawToken.unicodeScalars {
            let nextKind: SegmentKind
            if isCJKScalar(scalar) {
                nextKind = .cjkRun
            } else if CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar) {
                nextKind = .punctuationSuffix
            } else {
                nextKind = .word
            }

            if currentKind != nextKind {
                flush()
                currentKind = nextKind
            }
            buffer.unicodeScalars.append(scalar)
        }

        flush()
    }

    private func appendPunctuationSegments(
        _ punctuation: String,
        isPrefixContext: Bool,
        attributes: [NSAttributedString.Key: Any],
        segments: inout [PreparedSegment]
    ) {
        guard !punctuation.isEmpty else {
            return
        }

        var prefix = ""
        var suffix = ""

        for character in punctuation {
            if isOpeningPunctuation(character), suffix.isEmpty {
                prefix.append(character)
            } else {
                suffix.append(character)
            }
        }

        if !prefix.isEmpty {
            segments.append(makeSegment(kind: .punctuationPrefix, text: prefix, attributes: attributes))
        }

        if !suffix.isEmpty {
            let kind: SegmentKind = isPrefixContext ? .punctuationPrefix : .punctuationSuffix
            segments.append(makeSegment(kind: kind, text: suffix, attributes: attributes))
        }
    }

    private func classifyStandaloneToken(_ token: String) -> SegmentKind {
        if token.contains("\u{00A0}") {
            return .glue
        }

        if token.unicodeScalars.allSatisfy(isCJKScalar) {
            return .cjkRun
        }

        if isURLLikeToken(token) {
            return .urlLike
        }

        return .word
    }

    private func isURLLikeToken(_ token: String) -> Bool {
        if token.hasPrefix("@") || token.hasPrefix("#") || token.hasPrefix("/") {
            return token.count > 1
        }

        if token.contains("://") || token.lowercased().hasPrefix("www.") {
            return true
        }

        if token.contains("@"), token.contains(".") {
            return true
        }

        if token.contains("/") && (token.contains(".") || token.contains("?") || token.contains("=") || token.contains("&")) {
            return true
        }

        return false
    }

    private func isConnectorWordToken(_ token: String) -> Bool {
        guard token.contains("-") || token.contains("_") else {
            return false
        }

        guard !isURLLikeToken(token) else {
            return false
        }

        var sawAlphanumeric = false
        var previousWasConnector = false

        for scalar in token.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                sawAlphanumeric = true
                previousWasConnector = false
                continue
            }

            if scalar == "-" || scalar == "_" {
                if previousWasConnector {
                    return false
                }
                previousWasConnector = true
                continue
            }

            return false
        }

        return sawAlphanumeric && !previousWasConnector
    }

    private func shouldCollapseWhitespace(_ character: Character) -> Bool {
        character == "\n" || character == "\t" || character == " " || character.isWhitespace
    }

    private func isPreservedWhitespace(_ character: Character) -> Bool {
        character != "\n" && character != "\t" && character.isWhitespace
    }

    private func isOpeningPunctuation(_ character: Character) -> Bool {
        CharacterSet(charactersIn: "([{\"'“‘«〈《「『【〔").contains(character)
    }

    private func isCJKScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x1100...0x11FF, 0x2E80...0x2EFF, 0x2F00...0x2FDF, 0x3000...0x303F,
             0x3040...0x309F, 0x30A0...0x30FF, 0x31F0...0x31FF, 0x3400...0x4DBF,
             0x4E00...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }

    private func tokenizerLanguage() -> NLLanguage? {
        guard let localeIdentifier = options.localeIdentifier else {
            return nil
        }

        let locale = Locale(identifier: localeIdentifier)
        if #available(macOS 13.0, iOS 16.0, *) {
            if let code = locale.language.languageCode?.identifier {
                return NLLanguage(rawValue: code)
            }
        }

        let components = localeIdentifier.split(separator: "_")
        guard let first = components.first else {
            return nil
        }
        return NLLanguage(rawValue: String(first))
    }

    private func makeWhitespaceSegment(text: String, attributes: [NSAttributedString.Key: Any]) -> PreparedSegment {
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let metrics = segmentMetrics(for: attributedText)
        let lineEndPaintAdvance: CGFloat

        switch options.whiteSpaceMode {
        case .preWrap:
            lineEndPaintAdvance = metrics.width
        case .uikitLiteral, .cssNormal:
            lineEndPaintAdvance = max(metrics.width - metrics.trailingWhitespaceWidth, 0)
        }

        return PreparedSegment(
            kind: .whitespace,
            attributedText: attributedText,
            string: text,
            continueAdvance: metrics.width,
            lineEndFitAdvance: metrics.width,
            lineEndPaintAdvance: lineEndPaintAdvance,
            trailingWhitespaceWidth: metrics.trailingWhitespaceWidth,
            graphemeAdvances: metrics.graphemeAdvances,
            graphemePrefixAdvances: metrics.graphemePrefixAdvances,
            graphemeUTF16Offsets: metrics.graphemeUTF16Offsets,
            discretionaryHyphenAdvance: 0,
            preferredBreakGraphemeIndices: []
        )
    }

    private func makeSegment(kind: SegmentKind, text: String, attributes: [NSAttributedString.Key: Any]) -> PreparedSegment {
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let metrics = segmentMetrics(for: attributedText)
        let preferredBreaks = preferredBreakGraphemeIndices(for: kind, text: text)
        let hyphenAdvance: CGFloat
        if kind == .softHyphen {
            hyphenAdvance = segmentMetrics(for: NSAttributedString(string: "-", attributes: attributes)).width
        } else {
            hyphenAdvance = 0
        }

        switch kind {
        case .word, .punctuationPrefix, .punctuationSuffix, .urlLike, .cjkRun:
            return PreparedSegment(
                kind: kind,
                attributedText: attributedText,
                string: text,
                continueAdvance: metrics.width,
                lineEndFitAdvance: metrics.width,
                lineEndPaintAdvance: metrics.width,
                trailingWhitespaceWidth: metrics.trailingWhitespaceWidth,
                graphemeAdvances: metrics.graphemeAdvances,
                graphemePrefixAdvances: metrics.graphemePrefixAdvances,
                graphemeUTF16Offsets: metrics.graphemeUTF16Offsets,
                discretionaryHyphenAdvance: 0,
                preferredBreakGraphemeIndices: preferredBreaks
            )

        case .whitespace:
            return makeWhitespaceSegment(text: text, attributes: attributes)

        case .glue:
            return PreparedSegment(
                kind: kind,
                attributedText: attributedText,
                string: text,
                continueAdvance: metrics.width,
                lineEndFitAdvance: metrics.width,
                lineEndPaintAdvance: metrics.width,
                trailingWhitespaceWidth: metrics.trailingWhitespaceWidth,
                graphemeAdvances: metrics.graphemeAdvances,
                graphemePrefixAdvances: metrics.graphemePrefixAdvances,
                graphemeUTF16Offsets: metrics.graphemeUTF16Offsets,
                discretionaryHyphenAdvance: 0,
                preferredBreakGraphemeIndices: preferredBreaks
            )

        case .tab:
            return PreparedSegment(
                kind: kind,
                attributedText: attributedText,
                string: text,
                continueAdvance: 0,
                lineEndFitAdvance: 0,
                lineEndPaintAdvance: 0,
                trailingWhitespaceWidth: 0,
                graphemeAdvances: [0],
                graphemePrefixAdvances: [0, 0],
                graphemeUTF16Offsets: [0, text.utf16.count],
                discretionaryHyphenAdvance: 0,
                preferredBreakGraphemeIndices: []
            )

        case .zeroWidthBreak, .hardBreak:
            return PreparedSegment(
                kind: kind,
                attributedText: attributedText,
                string: text,
                continueAdvance: 0,
                lineEndFitAdvance: 0,
                lineEndPaintAdvance: 0,
                trailingWhitespaceWidth: 0,
                graphemeAdvances: [0],
                graphemePrefixAdvances: [0, 0],
                graphemeUTF16Offsets: [0, text.utf16.count],
                discretionaryHyphenAdvance: 0,
                preferredBreakGraphemeIndices: []
            )

        case .softHyphen:
            return PreparedSegment(
                kind: kind,
                attributedText: attributedText,
                string: text,
                continueAdvance: 0,
                lineEndFitAdvance: 0,
                lineEndPaintAdvance: 0,
                trailingWhitespaceWidth: 0,
                graphemeAdvances: [0],
                graphemePrefixAdvances: [0, 0],
                graphemeUTF16Offsets: [0, text.utf16.count],
                discretionaryHyphenAdvance: hyphenAdvance,
                preferredBreakGraphemeIndices: []
            )
        }
    }

    private func preferredBreakGraphemeIndices(for kind: SegmentKind, text: String) -> [Int] {
        guard kind == .urlLike else {
            return []
        }

        let characters = Array(text)
        guard characters.count > 1 else {
            return []
        }

        var breakpoints = Set<Int>()

        if let first = characters.first, first == "@" || first == "#" {
            for (index, character) in characters.enumerated().dropFirst() where character == "-" || character == "_" {
                breakpoints.insert(index + 1)
            }
            return breakpoints.sorted()
        }

        var index = 0
        while index < characters.count {
            if index + 2 < characters.count,
               characters[index] == ":",
               characters[index + 1] == "/",
               characters[index + 2] == "/" {
                breakpoints.insert(index + 3)
                index += 3
                continue
            }

            switch characters[index] {
            case "/", "?", "&", ".", "-", "_":
                breakpoints.insert(index + 1)
            default:
                break
            }
            index += 1
        }

        return breakpoints
            .filter { $0 > 0 && $0 < characters.count }
            .sorted()
    }

    private func segmentMetrics(for attributedText: NSAttributedString) -> SegmentMeasurementCache.Metrics {
        let signature = attributedText.pretextLayoutSignature()
        let key = SegmentMeasurementKey(
            identity: .attributed(signature)
        )

        if let cached = segmentMeasurementCache.metric(for: key) {
            return cached
        }

        let line = CTLineCreateWithAttributedString(attributedText as CFAttributedString)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let trailingWhitespaceWidth = CGFloat(CTLineGetTrailingWhitespaceWidth(line))
        let string = attributedText.string
        let graphemes = string.map(String.init)

        var advances: [CGFloat] = []
        var prefixes: [CGFloat] = [0]
        var offsets: [Int] = [0]
        var offset = 0

        for (index, grapheme) in graphemes.enumerated() {
            let endOffset = offset + grapheme.utf16.count
            let caretOffset = CGFloat(CTLineGetOffsetForStringIndex(line, endOffset, nil))
            let graphemeWidth = caretOffset - prefixes[index]
            advances.append(graphemeWidth)
            prefixes.append(prefixes[index] + graphemeWidth)
            offsets.append(endOffset)
            offset = endOffset
        }

        let metrics = SegmentMeasurementCache.Metrics(
            width: width,
            trailingWhitespaceWidth: trailingWhitespaceWidth,
            graphemeAdvances: advances,
            graphemePrefixAdvances: prefixes,
            graphemeUTF16Offsets: offsets
        )
        segmentMeasurementCache.insert(metrics, for: key)
        return metrics
    }

    private func lineHeight(for attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let fontLineHeight = fontLineHeight(from: attributes)

        if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
            let maxLineHeight = max(paragraphStyle.minimumLineHeight, paragraphStyle.maximumLineHeight)
            if maxLineHeight > 0 {
                return max(maxLineHeight, fontLineHeight)
            }
            if paragraphStyle.lineHeightMultiple > 0 {
                return max(fontLineHeight * paragraphStyle.lineHeightMultiple, fontLineHeight)
            }
        }

        return fontLineHeight
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

    private func normalizedLineBreaks(in attributedText: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(string: "")
        let string = attributedText.string
        var index = string.startIndex

        while index < string.endIndex {
            let character = string[index]
            let nextIndex = string.index(after: index)
            let range = NSRange(index..<nextIndex, in: string)
            let attributes = attributedText.attributes(at: range.location, effectiveRange: nil)

            if character == "\r" {
                if nextIndex < string.endIndex, string[nextIndex] == "\n" {
                    mutable.append(NSAttributedString(string: "\n", attributes: attributes))
                    index = string.index(after: nextIndex)
                } else {
                    mutable.append(NSAttributedString(string: "\n", attributes: attributes))
                    index = nextIndex
                }
                continue
            }

            mutable.append(attributedText.attributedSubstring(from: range))
            index = nextIndex
        }

        return mutable
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
}

private extension CharacterSet {
    func contains(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(contains)
    }
}
