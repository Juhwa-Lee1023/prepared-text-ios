#if canImport(UIKit) && canImport(SwiftUI) && !os(macOS)
import PretextCore
import UIKit

extension String {
    @MainActor
    public func prepared(
        attributes: [NSAttributedString.Key: Any]? = nil,
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        measurementOptions: PreparedTextMeasurementOptions = .default,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) -> PreparedTextView {
        PreparedTextView(
            attributedText: NSAttributedString(string: self, attributes: attributes),
            sourceID: sourceID,
            whiteSpaceMode: whiteSpaceMode,
            lineHeightOverride: lineHeightOverride,
            measurementOptions: measurementOptions,
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

extension AttributedString {
    @MainActor
    public func prepared(
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        measurementOptions: PreparedTextMeasurementOptions = .default,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) -> PreparedTextView {
        PreparedTextView(
            attributedText: NSAttributedString(self),
            sourceID: sourceID,
            whiteSpaceMode: whiteSpaceMode,
            lineHeightOverride: lineHeightOverride,
            measurementOptions: measurementOptions,
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

extension NSAttributedString {
    @MainActor
    public func prepared(
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        measurementOptions: PreparedTextMeasurementOptions = .default,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) -> PreparedTextView {
        PreparedTextView(
            attributedText: self,
            sourceID: sourceID,
            whiteSpaceMode: whiteSpaceMode,
            lineHeightOverride: lineHeightOverride,
            measurementOptions: measurementOptions,
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

extension PreparedText {
    @MainActor
    public func prepared(
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        measurementOptions: PreparedTextMeasurementOptions = .default,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil,
        layoutBehavior: PreparedTextLayoutBehavior = .hugContents
    ) -> PreparedTextView {
        PreparedTextView(
            preparedText: self,
            whiteSpaceMode: whiteSpaceMode,
            lineHeightOverride: lineHeightOverride,
            measurementOptions: measurementOptions,
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
#endif
