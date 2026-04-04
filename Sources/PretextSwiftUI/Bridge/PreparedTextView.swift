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
    public var layoutOptions: PreparedTextLayoutOptions
    public var automaticallyOpensLinks: Bool
    public var linkTapHandler: ((URL) -> Void)?
    public var layoutBehavior: PreparedTextLayoutBehavior

    public var numberOfLines: Int {
        get { layoutOptions.maximumNumberOfLines }
        set { layoutOptions.maximumNumberOfLines = max(newValue, 0) }
    }

    public var lineBreakMode: NSLineBreakMode {
        get { layoutOptions.lineBreakMode.nsLineBreakMode }
        set { layoutOptions.lineBreakMode = PreparedTextLineBreakMode(newValue) }
    }

    public var lineBreakStrategy: PreparedTextLineBreakStrategy {
        get { layoutOptions.lineBreakStrategy }
        set { layoutOptions.lineBreakStrategy = newValue }
    }

    public var textAlignment: NSTextAlignment? {
        get { layoutOptions.alignment.nsTextAlignment }
        set { layoutOptions.alignment = PreparedTextHorizontalAlignment(newValue) }
    }

    public init(
        attributedText: NSAttributedString,
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        measurementOptions: PreparedTextMeasurementOptions = .default,
        maxLayoutWidth: CGFloat? = nil,
        layoutOptions: PreparedTextLayoutOptions? = nil,
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
        self.layoutOptions = layoutOptions ?? PreparedTextLayoutOptions(
            maximumNumberOfLines: numberOfLines,
            lineBreakMode: PreparedTextLineBreakMode(lineBreakMode),
            alignment: PreparedTextHorizontalAlignment(textAlignment),
            layoutDirection: .natural
        )
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
        layoutOptions: PreparedTextLayoutOptions? = nil,
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
        self.layoutOptions = layoutOptions ?? PreparedTextLayoutOptions(
            maximumNumberOfLines: numberOfLines,
            lineBreakMode: PreparedTextLineBreakMode(lineBreakMode),
            alignment: PreparedTextHorizontalAlignment(textAlignment),
            layoutDirection: .natural
        )
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
                layoutOptions: layoutOptions,
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

extension PreparedTextLineBreakMode {
    init(_ value: NSLineBreakMode) {
        switch value {
        case .byWordWrapping:
            self = .wordWrap
        case .byCharWrapping:
            self = .characterWrap
        case .byClipping:
            self = .clip
        case .byTruncatingHead:
            self = .truncateHead
        case .byTruncatingMiddle:
            self = .truncateMiddle
        case .byTruncatingTail:
            self = .truncateTail
        @unknown default:
            self = .truncateTail
        }
    }

    var nsLineBreakMode: NSLineBreakMode {
        switch self {
        case .wordWrap:
            return .byWordWrapping
        case .characterWrap:
            return .byCharWrapping
        case .clip:
            return .byClipping
        case .truncateHead:
            return .byTruncatingHead
        case .truncateMiddle:
            return .byTruncatingMiddle
        case .truncateTail:
            return .byTruncatingTail
        }
    }
}

extension PreparedTextHorizontalAlignment {
    init(_ value: NSTextAlignment?) {
        switch value ?? .natural {
        case .center:
            self = .center
        case .right:
            self = .right
        case .left:
            self = .left
        case .natural, .justified:
            self = .natural
        @unknown default:
            self = .natural
        }
    }

    var nsTextAlignment: NSTextAlignment? {
        switch self {
        case .natural:
            return nil
        case .left:
            return .left
        case .leading:
            return .left
        case .center:
            return .center
        case .trailing:
            return .right
        case .right:
            return .right
        }
    }
}
#endif
