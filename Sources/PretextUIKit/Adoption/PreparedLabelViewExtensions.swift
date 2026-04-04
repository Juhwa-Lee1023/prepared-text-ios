#if canImport(UIKit) && !os(macOS)
import PretextCore
import UIKit

extension PreparedLabelView {
    @discardableResult
    public func prepared(
        attributedText: NSAttributedString? = nil,
        preparedText: PreparedText? = nil,
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        maxLayoutWidth: CGFloat? = nil,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment? = nil,
        automaticallyOpensLinks: Bool = true,
        linkTapHandler: ((URL) -> Void)? = nil
    ) -> Self {
        apply(
            configuration: PreparedLabelConfiguration(
                attributedText: attributedText,
                preparedText: preparedText,
                sourceID: sourceID,
                whiteSpaceMode: whiteSpaceMode,
                lineHeightOverride: lineHeightOverride,
                maxLayoutWidth: maxLayoutWidth,
                numberOfLines: numberOfLines,
                lineBreakMode: lineBreakMode,
                textAlignment: textAlignment,
                automaticallyOpensLinks: automaticallyOpensLinks,
                linkTapHandler: linkTapHandler
            )
        )
        return self
    }
}
#endif
