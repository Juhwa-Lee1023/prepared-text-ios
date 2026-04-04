import CoreGraphics
import CoreText
import Foundation

/// White-space behaviors supported by the prepared-text pipeline.
///
/// - `uikitLiteral`: preserves ordinary spaces, tabs, and hard breaks in a UIKit-like
///   read-only rendering model. This is the v1 default and the safest migration path for
///   chat/feed/list/card surfaces.
/// - `cssNormal`: collapses consecutive spaces and trims line-leading collapsed whitespace.
///   It is intentionally CSS-like and does not imply UILabel parity.
/// - `preWrap`: preserves spaces and hard breaks similarly to CSS `pre-wrap`.
public enum WhiteSpaceMode: String, Hashable, Sendable {
    case uikitLiteral
    case cssNormal
    case preWrap
}

public struct PreparedTextSourceID: RawRepresentable, Hashable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct PreparedTextOptions: Hashable, Sendable {
    public var whiteSpaceMode: WhiteSpaceMode
    public var localeIdentifier: String?

    /// Defaults to `uikitLiteral` for conservative read-only Apple UI behavior.
    public init(
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        locale: Locale? = nil
    ) {
        self.whiteSpaceMode = whiteSpaceMode
        self.localeIdentifier = locale?.identifier
    }
}

public struct LayoutCursor: Hashable, Sendable, Comparable {
    public var segmentIndex: Int
    public var graphemeIndex: Int

    public init(segmentIndex: Int = 0, graphemeIndex: Int = 0) {
        self.segmentIndex = segmentIndex
        self.graphemeIndex = graphemeIndex
    }

    public static func < (lhs: LayoutCursor, rhs: LayoutCursor) -> Bool {
        if lhs.segmentIndex == rhs.segmentIndex {
            return lhs.graphemeIndex < rhs.graphemeIndex
        }
        return lhs.segmentIndex < rhs.segmentIndex
    }
}

public struct LineFragment: Hashable, Sendable {
    public var start: LayoutCursor
    public var end: LayoutCursor
    public var paintEnd: LayoutCursor
    public var fitWidth: CGFloat
    public var paintWidth: CGFloat
    public var trailingWhitespaceWidth: CGFloat
    public var ascent: CGFloat
    public var descent: CGFloat
    public var leading: CGFloat
    public var blockAdvance: CGFloat
    public var paragraphSpacingBefore: CGFloat
    public var paragraphSpacingAfter: CGFloat

    public init(
        start: LayoutCursor,
        end: LayoutCursor,
        paintEnd: LayoutCursor,
        fitWidth: CGFloat,
        paintWidth: CGFloat,
        trailingWhitespaceWidth: CGFloat,
        ascent: CGFloat,
        descent: CGFloat,
        leading: CGFloat,
        blockAdvance: CGFloat,
        paragraphSpacingBefore: CGFloat = 0,
        paragraphSpacingAfter: CGFloat = 0
    ) {
        self.start = start
        self.end = end
        self.paintEnd = paintEnd
        self.fitWidth = fitWidth
        self.paintWidth = paintWidth
        self.trailingWhitespaceWidth = trailingWhitespaceWidth
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.blockAdvance = blockAdvance
        self.paragraphSpacingBefore = paragraphSpacingBefore
        self.paragraphSpacingAfter = paragraphSpacingAfter
    }
}

public struct LayoutResult: Hashable, Sendable {
    public var fragments: [LineFragment]
    public var height: CGFloat
    public var maxPaintWidth: CGFloat

    public init(fragments: [LineFragment], height: CGFloat, maxPaintWidth: CGFloat) {
        self.fragments = fragments
        self.height = height
        self.maxPaintWidth = maxPaintWidth
    }

    public var lineCount: Int {
        fragments.count
    }
}

public struct PreparedDrawLine {
    public var fragment: LineFragment
    public var attributedText: NSAttributedString
    public var ctLine: CTLine

    public init(fragment: LineFragment, attributedText: NSAttributedString, ctLine: CTLine) {
        self.fragment = fragment
        self.attributedText = attributedText
        self.ctLine = ctLine
    }
}

public struct PreparedLayoutPacket {
    public var result: LayoutResult
    public var lines: [PreparedDrawLine]

    public init(result: LayoutResult, lines: [PreparedDrawLine]) {
        self.result = result
        self.lines = lines
    }
}

public struct LineResult: Hashable, Sendable {
    public var width: CGFloat
    public var paintWidth: CGFloat
    public var start: LayoutCursor
    public var end: LayoutCursor
    public var paintEnd: LayoutCursor
    public var discretionaryHyphenSegmentIndex: Int?
    public var text: String?

    public init(
        width: CGFloat,
        paintWidth: CGFloat,
        start: LayoutCursor,
        end: LayoutCursor,
        paintEnd: LayoutCursor,
        discretionaryHyphenSegmentIndex: Int? = nil,
        text: String? = nil
    ) {
        self.width = width
        self.paintWidth = paintWidth
        self.start = start
        self.end = end
        self.paintEnd = paintEnd
        self.discretionaryHyphenSegmentIndex = discretionaryHyphenSegmentIndex
        self.text = text
    }
}

public enum SegmentKind: Hashable, Sendable {
    case word
    case punctuationPrefix
    case punctuationSuffix
    case urlLike
    case cjkRun
    case whitespace
    case tab
    case glue
    case softHyphen
    case zeroWidthBreak
    case hardBreak
}

struct PreparedSegment {
    var kind: SegmentKind
    var attributedText: NSAttributedString
    var string: String
    var continueAdvance: CGFloat
    var lineEndFitAdvance: CGFloat
    var lineEndPaintAdvance: CGFloat
    var trailingWhitespaceWidth: CGFloat
    var graphemeAdvances: [CGFloat]
    var graphemePrefixAdvances: [CGFloat]
    var graphemeUTF16Offsets: [Int]
    var discretionaryHyphenAdvance: CGFloat
    var preferredBreakGraphemeIndices: [Int]

    var graphemeCount: Int {
        max(graphemeUTF16Offsets.count - 1, 0)
    }

    var allowsInternalWrapping: Bool {
        switch kind {
        case .word, .urlLike, .cjkRun, .whitespace:
            return true
        default:
            return false
        }
    }
}

struct PreparedTextCore {
    var segments: [PreparedSegment]
    var defaultLineHeight: CGFloat
    var tabStopAdvance: CGFloat
    var prefersNativeLineBreaking: Bool
}

final class PreparedTextStorage {
    let source: NSAttributedString
    let core: PreparedTextCore
    let options: PreparedTextOptions
    let sourceID: PreparedTextSourceID?
    let nativeLineBreakingSource: NSAttributedString?
    let nativeTypesetter: CTTypesetter?

    init(
        source: NSAttributedString,
        core: PreparedTextCore,
        options: PreparedTextOptions,
        sourceID: PreparedTextSourceID?,
        nativeLineBreakingSource: NSAttributedString?,
        nativeTypesetter: CTTypesetter?
    ) {
        self.source = source
        self.core = core
        self.options = options
        self.sourceID = sourceID
        self.nativeLineBreakingSource = nativeLineBreakingSource
        self.nativeTypesetter = nativeTypesetter
    }
}

public struct PreparedText: Hashable {
    let storage: PreparedTextStorage

    init(storage: PreparedTextStorage) {
        self.storage = storage
    }

    public var defaultLineHeight: CGFloat {
        storage.core.defaultLineHeight
    }

    public var source: NSAttributedString {
        storage.source
    }

    public var sourceID: PreparedTextSourceID? {
        storage.sourceID
    }

    public static func == (lhs: PreparedText, rhs: PreparedText) -> Bool {
        lhs.storage === rhs.storage
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(storage))
    }
}
