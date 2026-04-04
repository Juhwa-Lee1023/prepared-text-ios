#if canImport(UIKit) && canImport(SwiftUI) && !os(macOS)
import PretextCore
import SwiftUI
import UIKit

/// Convenience SwiftUI wrapper for common read-only prepared-text copy.
///
/// `PreparedCopy` is sugar over `PreparedTextView`. It supports plain strings,
/// `AttributedString`, `NSAttributedString`, and precomputed `PreparedText` handles.
/// It does not attempt to convert SwiftUI's opaque `Text` type.
@MainActor
public struct PreparedCopy: View {
    private enum Storage {
        case attributed(NSAttributedString, PreparedTextSourceID?)
        case prepared(PreparedText)
    }

    private let storage: Storage
    private let whiteSpaceMode: WhiteSpaceMode
    private let lineHeightOverride: CGFloat?
    private let maxLayoutWidth: CGFloat?
    private let numberOfLines: Int
    private let lineBreakMode: NSLineBreakMode
    private let textAlignment: NSTextAlignment?
    private let automaticallyOpensLinks: Bool
    private let linkTapHandler: ((URL) -> Void)?
    private let layoutBehavior: PreparedTextLayoutBehavior

    public init(
        _ string: String,
        attributes: [NSAttributedString.Key: Any]? = nil,
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) {
        self.storage = .attributed(
            NSAttributedString(string: string, attributes: attributes),
            sourceID
        )
        self.whiteSpaceMode = whiteSpaceMode
        self.lineHeightOverride = lineHeightOverride
        self.maxLayoutWidth = maxLayoutWidth
        self.numberOfLines = max(numberOfLines, 0)
        self.lineBreakMode = lineBreakMode
        self.textAlignment = textAlignment
        self.automaticallyOpensLinks = automaticallyOpensLinks
        self.linkTapHandler = linkTapHandler
        self.layoutBehavior = layoutBehavior
    }

    public init(
        _ attributedString: AttributedString,
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) {
        self.storage = .attributed(NSAttributedString(attributedString), sourceID)
        self.whiteSpaceMode = whiteSpaceMode
        self.lineHeightOverride = lineHeightOverride
        self.maxLayoutWidth = maxLayoutWidth
        self.numberOfLines = max(numberOfLines, 0)
        self.lineBreakMode = lineBreakMode
        self.textAlignment = textAlignment
        self.automaticallyOpensLinks = automaticallyOpensLinks
        self.linkTapHandler = linkTapHandler
        self.layoutBehavior = layoutBehavior
    }

    public init(
        _ attributedText: NSAttributedString,
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) {
        self.storage = .attributed(attributedText, sourceID)
        self.whiteSpaceMode = whiteSpaceMode
        self.lineHeightOverride = lineHeightOverride
        self.maxLayoutWidth = maxLayoutWidth
        self.numberOfLines = max(numberOfLines, 0)
        self.lineBreakMode = lineBreakMode
        self.textAlignment = textAlignment
        self.automaticallyOpensLinks = automaticallyOpensLinks
        self.linkTapHandler = linkTapHandler
        self.layoutBehavior = layoutBehavior
    }

    public init(
        _ preparedText: PreparedText,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) {
        self.storage = .prepared(preparedText)
        self.whiteSpaceMode = whiteSpaceMode
        self.lineHeightOverride = lineHeightOverride
        self.maxLayoutWidth = maxLayoutWidth
        self.numberOfLines = max(numberOfLines, 0)
        self.lineBreakMode = lineBreakMode
        self.textAlignment = textAlignment
        self.automaticallyOpensLinks = automaticallyOpensLinks
        self.linkTapHandler = linkTapHandler
        self.layoutBehavior = layoutBehavior
    }

    public var body: some View {
        switch storage {
        case let .attributed(attributedText, sourceID):
            PreparedTextView(
                attributedText: attributedText,
                sourceID: sourceID,
                whiteSpaceMode: whiteSpaceMode,
                lineHeightOverride: lineHeightOverride,
                maxLayoutWidth: maxLayoutWidth,
                numberOfLines: numberOfLines,
                lineBreakMode: lineBreakMode,
                textAlignment: textAlignment,
                automaticallyOpensLinks: automaticallyOpensLinks,
                linkTapHandler: linkTapHandler,
                layoutBehavior: layoutBehavior
            )

        case let .prepared(preparedText):
            PreparedTextView(
                preparedText: preparedText,
                whiteSpaceMode: whiteSpaceMode,
                lineHeightOverride: lineHeightOverride,
                maxLayoutWidth: maxLayoutWidth,
                numberOfLines: numberOfLines,
                lineBreakMode: lineBreakMode,
                textAlignment: textAlignment,
                automaticallyOpensLinks: automaticallyOpensLinks,
                linkTapHandler: linkTapHandler,
                layoutBehavior: layoutBehavior
            )
        }
    }
}
#endif
