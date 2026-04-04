#if canImport(UIKit) && canImport(SwiftUI) && !os(macOS)
import PretextCore
import PretextUIKit
import SwiftUI
import UIKit

public enum PreparedTextLayoutBehavior: Hashable, Sendable {
    case hugContents
    case fillProposal
}

/// SwiftUI bridge for the read-only UIKit prepared-text renderer.
///
/// This surface does not replace SwiftUI's native `Text`; it hosts `PreparedLabelView`
/// when callers want the same prepared-text sizing and draw behavior inside a SwiftUI tree.
public struct PreparedTextView: UIViewRepresentable {
    private let attributedText: NSAttributedString?
    private let preparedText: PreparedText?
    private let sourceID: PreparedTextSourceID?

    public var whiteSpaceMode: WhiteSpaceMode
    public var lineHeightOverride: CGFloat?
    public var measurementOptions: PreparedTextMeasurementOptions
    public var maxLayoutWidth: CGFloat?
    public var numberOfLines: Int
    public var lineBreakMode: NSLineBreakMode
    public var textAlignment: NSTextAlignment?
    public var automaticallyOpensLinks: Bool
    public var linkTapHandler: ((URL) -> Void)?
    public var layoutBehavior: PreparedTextLayoutBehavior

    public init(
        attributedText: NSAttributedString,
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
    ) {
        self.attributedText = attributedText
        self.preparedText = nil
        self.sourceID = sourceID
        self.whiteSpaceMode = whiteSpaceMode
        self.lineHeightOverride = lineHeightOverride
        self.measurementOptions = measurementOptions
        self.maxLayoutWidth = maxLayoutWidth
        self.numberOfLines = max(numberOfLines, 0)
        self.lineBreakMode = lineBreakMode
        self.textAlignment = textAlignment
        self.automaticallyOpensLinks = automaticallyOpensLinks
        self.linkTapHandler = linkTapHandler
        self.layoutBehavior = layoutBehavior
    }

    public init(
        preparedText: PreparedText,
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
    ) {
        self.attributedText = nil
        self.preparedText = preparedText
        self.sourceID = preparedText.sourceID
        self.whiteSpaceMode = whiteSpaceMode
        self.lineHeightOverride = lineHeightOverride
        self.measurementOptions = measurementOptions
        self.maxLayoutWidth = maxLayoutWidth
        self.numberOfLines = max(numberOfLines, 0)
        self.lineBreakMode = lineBreakMode
        self.textAlignment = textAlignment
        self.automaticallyOpensLinks = automaticallyOpensLinks
        self.linkTapHandler = linkTapHandler
        self.layoutBehavior = layoutBehavior
    }

    public func makeUIView(context _: Context) -> PreparedLabelView {
        let view = PreparedLabelView()
        view.backgroundColor = .clear
        return view
    }

    public func updateUIView(_ uiView: PreparedLabelView, context _: Context) {
        uiView.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: attributedText,
                preparedText: preparedText,
                sourceID: sourceID,
                whiteSpaceMode: whiteSpaceMode,
                lineHeightOverride: lineHeightOverride,
                measurementOptions: measurementOptions,
                maxLayoutWidth: maxLayoutWidth,
                numberOfLines: numberOfLines,
                lineBreakMode: lineBreakMode,
                textAlignment: textAlignment,
                automaticallyOpensLinks: automaticallyOpensLinks,
                linkTapHandler: linkTapHandler
            )
        )
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: PreparedLabelView, context _: Context) -> CGSize? {
        let width = proposal.width ?? maxLayoutWidth ?? uiView.bounds.width
        guard width > 0 else {
            return uiView.intrinsicContentSize
        }

        let measured = uiView.sizeThatFits(CGSize(width: width, height: proposal.height ?? .greatestFiniteMagnitude))
        switch layoutBehavior {
        case .hugContents:
            return measured
        case .fillProposal:
            return CGSize(width: width, height: measured.height)
        }
    }
}
#endif
