#if canImport(UIKit) && canImport(SwiftUI) && !os(macOS)
import PretextCore
import SwiftUI
import UIKit

public extension Text {
    /// Experimental convenience syntax for source-driven prepared rendering.
    ///
    /// The `source` parameter is authoritative: it supplies the content that will be
    /// prepared, measured, and rendered. The `Text` receiver is not introspected, and
    /// modifiers already applied to the original `Text` are not automatically preserved.
    ///
    /// This overload exists only for call-site ergonomics such as
    /// `Text("Hello").prepared(source: "Hello")`.
    /// For stable and explicit usage, prefer `String.prepared()`,
    /// `AttributedString.prepared()`, `NSAttributedString.prepared()`, or `PreparedCopy(...)`.
    @MainActor
    func prepared(
        source: String,
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        layoutOptions: PreparedTextLayoutOptions? = nil,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) -> PreparedTextView {
        source.prepared(
            sourceID: sourceID,
            whiteSpaceMode: whiteSpaceMode,
            lineHeightOverride: lineHeightOverride,
            maxLayoutWidth: maxLayoutWidth,
            layoutOptions: layoutOptions,
            numberOfLines: numberOfLines,
            lineBreakMode: lineBreakMode,
            textAlignment: textAlignment,
            automaticallyOpensLinks: automaticallyOpensLinks,
            linkTapHandler: linkTapHandler,
            layoutBehavior: layoutBehavior
        )
    }

    /// Experimental convenience syntax for source-driven prepared rendering.
    ///
    /// The `source` parameter is authoritative: it supplies the attributed content that will be
    /// prepared, measured, and rendered. The `Text` receiver is not introspected, and modifiers
    /// already applied to the original `Text` are not automatically preserved.
    @MainActor
    func prepared(
        source: AttributedString,
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        layoutOptions: PreparedTextLayoutOptions? = nil,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) -> PreparedTextView {
        source.prepared(
            sourceID: sourceID,
            whiteSpaceMode: whiteSpaceMode,
            lineHeightOverride: lineHeightOverride,
            maxLayoutWidth: maxLayoutWidth,
            layoutOptions: layoutOptions,
            numberOfLines: numberOfLines,
            lineBreakMode: lineBreakMode,
            textAlignment: textAlignment,
            automaticallyOpensLinks: automaticallyOpensLinks,
            linkTapHandler: linkTapHandler,
            layoutBehavior: layoutBehavior
        )
    }

    /// Experimental convenience syntax for source-driven prepared rendering.
    ///
    /// The `source` parameter is authoritative: it supplies the attributed content that will be
    /// prepared, measured, and rendered. The `Text` receiver is not introspected, and modifiers
    /// already applied to the original `Text` are not automatically preserved.
    @MainActor
    func prepared(
        source: NSAttributedString,
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        layoutOptions: PreparedTextLayoutOptions? = nil,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) -> PreparedTextView {
        source.prepared(
            sourceID: sourceID,
            whiteSpaceMode: whiteSpaceMode,
            lineHeightOverride: lineHeightOverride,
            maxLayoutWidth: maxLayoutWidth,
            layoutOptions: layoutOptions,
            numberOfLines: numberOfLines,
            lineBreakMode: lineBreakMode,
            textAlignment: textAlignment,
            automaticallyOpensLinks: automaticallyOpensLinks,
            linkTapHandler: linkTapHandler,
            layoutBehavior: layoutBehavior
        )
    }

    /// Experimental convenience syntax for source-driven prepared rendering.
    ///
    /// The `source` parameter is authoritative. The `Text` receiver is not introspected, and
    /// existing modifiers on the original `Text` are not automatically preserved.
    @MainActor
    func prepared(
        source: PreparedText,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        layoutOptions: PreparedTextLayoutOptions? = nil,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) -> PreparedTextView {
        source.prepared(
            whiteSpaceMode: whiteSpaceMode,
            lineHeightOverride: lineHeightOverride,
            maxLayoutWidth: maxLayoutWidth,
            layoutOptions: layoutOptions,
            numberOfLines: numberOfLines,
            lineBreakMode: lineBreakMode,
            textAlignment: textAlignment,
            automaticallyOpensLinks: automaticallyOpensLinks,
            linkTapHandler: linkTapHandler,
            layoutBehavior: layoutBehavior
        )
    }
}
#endif
