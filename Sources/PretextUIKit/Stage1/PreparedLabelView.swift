#if canImport(UIKit) && !os(macOS)
import CoreText
import PretextCore
import UIKit

public struct PreparedLabelConfiguration {
    public var attributedText: NSAttributedString?
    public var preparedText: PreparedText?
    public var sourceID: PreparedTextSourceID?
    public var whiteSpaceMode: WhiteSpaceMode
    public var lineHeightOverride: CGFloat?
    public var measurementOptions: PreparedTextMeasurementOptions
    public var maxLayoutWidth: CGFloat?
    public var layoutOptions: PreparedTextLayoutOptions
    public var automaticallyOpensLinks: Bool
    public var linkTapHandler: ((URL) -> Void)?

    public init(
        attributedText: NSAttributedString? = nil,
        preparedText: PreparedText? = nil,
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
        linkTapHandler: ((URL) -> Void)? = nil
    ) {
        self.attributedText = attributedText
        self.preparedText = preparedText
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
    }

    public var numberOfLines: Int {
        get { layoutOptions.maximumNumberOfLines }
        set { layoutOptions.maximumNumberOfLines = max(newValue, 0) }
    }

    public var lineBreakMode: NSLineBreakMode {
        get { layoutOptions.lineBreakMode.nsLineBreakMode }
        set { layoutOptions.lineBreakMode = PreparedTextLineBreakMode(newValue) }
    }

    public var textAlignment: NSTextAlignment? {
        get { layoutOptions.alignment.nsTextAlignment }
        set { layoutOptions.alignment = PreparedTextHorizontalAlignment(newValue) }
    }

    fileprivate func layoutSnapshot() -> PreparedLabelLayoutSnapshot {
        PreparedLabelLayoutSnapshot(configuration: self)
    }

    fileprivate func accessibilitySnapshot() -> PreparedLabelAccessibilitySnapshot {
        PreparedLabelAccessibilitySnapshot(configuration: self)
    }
}

/// Read-only multiline prepared-text renderer for self-sizing UIKit surfaces.
///
/// `PreparedLabelView` is intentionally narrower than `UILabel`: it focuses on
/// repeated width negotiation, predictable height measurement, prepared layout reuse,
/// and draw-time parity within chat/feed/list/card style UIs.
public final class PreparedLabelView: UIView {
    public var textSystem: PreparedTextSystem
    public private(set) var configuration = PreparedLabelConfiguration()
    private lazy var tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
    private var cachedDisplayPacket: CachedDisplayPacket?
    private var lastKnownBoundsWidth: CGFloat = 0
    private var lastAppliedLayoutSnapshot: PreparedLabelLayoutSnapshot?
    private var lastAppliedAccessibilitySnapshot: PreparedLabelAccessibilitySnapshot?

    public var numberOfLines: Int {
        get { configuration.numberOfLines }
        set {
            updateConfiguration { $0.numberOfLines = max(newValue, 0) }
        }
    }

    public var lineBreakMode: NSLineBreakMode {
        get { configuration.lineBreakMode }
        set {
            updateConfiguration { $0.lineBreakMode = newValue }
        }
    }

    public var textAlignment: NSTextAlignment {
        get { configuration.textAlignment ?? .natural }
        set {
            updateConfiguration { $0.textAlignment = newValue }
        }
    }

    public var layoutOptions: PreparedTextLayoutOptions {
        get { configuration.layoutOptions }
        set {
            updateConfiguration { $0.layoutOptions = newValue }
        }
    }

    public var automaticallyOpensLinks: Bool {
        get { configuration.automaticallyOpensLinks }
        set {
            updateConfiguration { $0.automaticallyOpensLinks = newValue }
        }
    }

    public var linkTapHandler: ((URL) -> Void)? {
        get { configuration.linkTapHandler }
        set {
            updateConfiguration { $0.linkTapHandler = newValue }
        }
    }

    public override init(frame: CGRect) {
        self.textSystem = .shared
        super.init(frame: frame)
        configureView()
    }

    public required init?(coder: NSCoder) {
        self.textSystem = .shared
        super.init(coder: coder)
        configureView()
    }

    public func apply(configuration: PreparedLabelConfiguration) {
        let layoutSnapshot = configuration.layoutSnapshot()
        let accessibilitySnapshot = configuration.accessibilitySnapshot()
        let needsLayoutInvalidation = lastAppliedLayoutSnapshot != layoutSnapshot
        let needsAccessibilityRefresh = lastAppliedAccessibilitySnapshot != accessibilitySnapshot
        self.configuration = configuration
        lastAppliedLayoutSnapshot = layoutSnapshot
        lastAppliedAccessibilitySnapshot = accessibilitySnapshot
        if needsAccessibilityRefresh {
            updateAccessibilityMetadata()
        }
        if needsLayoutInvalidation {
            invalidateLayout()
        }
    }

    public override var intrinsicContentSize: CGSize {
        guard resolvedInputText() != nil else {
            return .zero
        }

        return naturalMeasuredSize()
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard resolvedInputText() != nil else {
            return .zero
        }

        guard size.width.isFinite, size.width > 0 else {
            return naturalMeasuredSize()
        }

        return measuredSize(width: size.width, preserveProposedWidth: false)
    }

    public override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority _: UILayoutPriority
    ) -> CGSize {
        guard resolvedInputText() != nil else {
            return .zero
        }

        let width: CGFloat
        let preserveProposedWidth: Bool
        if horizontalFittingPriority == .required, targetSize.width.isFinite, targetSize.width > 0 {
            width = targetSize.width
            preserveProposedWidth = true
        } else if let maxLayoutWidth = configuration.maxLayoutWidth, maxLayoutWidth > 0 {
            width = maxLayoutWidth
            preserveProposedWidth = true
        } else if bounds.width > 0 {
            width = bounds.width
            preserveProposedWidth = true
        } else {
            width = resolvedMeasurementWidth(fallbackToSingleLine: true)
            preserveProposedWidth = false
        }

        return measuredSize(width: width, preserveProposedWidth: preserveProposedWidth)
    }

    public override func draw(_ rect: CGRect) {
        let layoutWidth = resolvedDrawWidth()
        let containerWidth = bounds.width > 0 ? bounds.width : layoutWidth
        guard let packet = resolvedDisplayPacket(layoutWidth: layoutWidth, containerWidth: containerWidth) else {
            return
        }

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)

        var consumedHeight: CGFloat = 0
        for line in packet.lines {
            let baselineY = max(
                bounds.height - consumedHeight - line.fragment.paragraphSpacingBefore - line.fragment.ascent,
                line.fragment.descent + line.fragment.leading
            )
            context.textPosition = CGPoint(x: line.originX, y: baselineY)
            CTLineDraw(line.ctLine, context)
            consumedHeight += line.fragment.blockAdvance
        }

        context.restoreGState()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let categoryChanged = previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory
        if categoryChanged {
            invalidateLayout()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else {
            return
        }

        if abs(bounds.width - lastKnownBoundsWidth) > 0.5 {
            lastKnownBoundsWidth = bounds.width
            updateAccessibilityMetadata()
            invalidateLayout()
        }
    }

    public override func accessibilityActivate() -> Bool {
        let visibleLinks = visibleLinks()
        guard visibleLinks.count == 1, let url = visibleLinks.first?.url else {
            return super.accessibilityActivate()
        }

        return activate(url: url)
    }

    public func link(at point: CGPoint) -> URL? {
        let layoutWidth = resolvedDrawWidth()
        let containerWidth = bounds.width > 0 ? bounds.width : layoutWidth
        guard let packet = resolvedDisplayPacket(layoutWidth: layoutWidth, containerWidth: containerWidth) else {
            return nil
        }

        var consumedHeight: CGFloat = 0
        for line in packet.lines {
            let lineFrame = line.frame(originY: consumedHeight)
            defer { consumedHeight += line.fragment.blockAdvance }
            guard lineFrame.contains(point) else {
                continue
            }

            let localX = point.x - line.originX
            guard localX >= 0, localX <= line.lineWidth else {
                continue
            }

            let index = CTLineGetStringIndexForPosition(line.ctLine, CGPoint(x: localX, y: 0))
            guard index != kCFNotFound, index >= 0, index < line.attributedText.length else {
                continue
            }

            if let url = line.attributedText.linkURL(at: index) {
                return url
            }
        }

        return nil
    }

    public func sourceCoordinateMap() -> PreparedTextSourceCoordinateMap? {
        let layoutWidth = resolvedDrawWidth()
        let containerWidth = bounds.width > 0 ? bounds.width : layoutWidth
        return resolvedDisplayPacket(layoutWidth: layoutWidth, containerWidth: containerWidth)?.sourceCoordinateMap
    }

    @discardableResult
    public func activateLink(at point: CGPoint) -> Bool {
        guard let url = link(at: point) else {
            return false
        }

        return activate(url: url)
    }

    private func configureView() {
        isOpaque = false
        contentMode = .redraw
        isAccessibilityElement = true
        isUserInteractionEnabled = true
        accessibilityTraits.insert(.staticText)
        tapGestureRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(tapGestureRecognizer)
        updateAccessibilityMetadata()
    }

    private func measuredSize(width: CGFloat, preserveProposedWidth: Bool) -> CGSize {
        guard let packet = resolvedDisplayPacket(layoutWidth: width, containerWidth: width) else {
            return .zero
        }

        let reportedWidth = preserveProposedWidth ? width : min(width, packet.result.maxPaintWidth)
        return CGSize(width: ceil(reportedWidth), height: ceil(packet.result.height))
    }

    private func naturalMeasuredSize() -> CGSize {
        let width = resolvedMeasurementWidth(fallbackToSingleLine: true)
        guard let packet = resolvedDisplayPacket(layoutWidth: width, containerWidth: width) else {
            return .zero
        }

        return CGSize(width: ceil(packet.result.maxPaintWidth), height: ceil(packet.result.height))
    }

    private func resolvedDrawWidth() -> CGFloat {
        if let maxLayoutWidth = configuration.maxLayoutWidth, maxLayoutWidth > 0 {
            return maxLayoutWidth
        }
        if bounds.width > 0 {
            return bounds.width
        }
        return resolvedMeasurementWidth(fallbackToSingleLine: true)
    }

    private func resolvedMeasurementWidth(fallbackToSingleLine: Bool) -> CGFloat {
        if let maxLayoutWidth = configuration.maxLayoutWidth, maxLayoutWidth > 0 {
            return maxLayoutWidth
        }
        if bounds.width > 0 {
            return bounds.width
        }
        return fallbackToSingleLine ? 10_000 : 0
    }

    private func resolvedPreparedText() -> PreparedText? {
        if let preparedText = configuration.preparedText {
            return preparedText
        }
        guard let attributedText = configuration.attributedText else {
            return nil
        }

        let options = PreparedTextOptions(
            whiteSpaceMode: configuration.whiteSpaceMode,
            locale: Locale.current
        )

        if let sourceID = configuration.sourceID {
            return textSystem.prepare(attributedText, sourceID: sourceID, options: options)
        }

        return textSystem.prepare(attributedText, options: options)
    }

    private func resolvedInputText() -> NSAttributedString? {
        configuration.preparedText?.source ?? configuration.attributedText
    }

    private func resolvedLayoutPacket(width: CGFloat) -> PreparedLayoutPacket? {
        guard let prepared = resolvedPreparedText() else {
            return nil
        }
        let lineHeight = configuration.lineHeightOverride ?? prepared.defaultLineHeight
        return textSystem.layoutPacket(prepared, maxWidth: width, lineHeight: lineHeight, env: measurementEnv())
    }

    private func resolvedDisplayPacket(layoutWidth: CGFloat, containerWidth: CGFloat) -> PreparedTextDisplayPacket? {
        guard let prepared = resolvedPreparedText() else {
            return nil
        }

        let resolvedLayoutWidth = max(layoutWidth, 0)
        let resolvedContainerWidth = max(containerWidth, resolvedLayoutWidth)
        if let cachedDisplayPacket,
           cachedDisplayPacket.matches(
               prepared: prepared,
               layoutWidth: resolvedLayoutWidth,
               containerWidth: resolvedContainerWidth,
               layoutOptions: resolvedLayoutOptions()
           ) {
            return cachedDisplayPacket.packet
        }

        let lineHeight = configuration.lineHeightOverride ?? prepared.defaultLineHeight
        let displayPacket = textSystem.displayLayoutPacket(
            prepared,
            maxWidth: resolvedLayoutWidth,
            lineHeight: lineHeight,
            containerWidth: resolvedContainerWidth,
            env: measurementEnv(),
            options: resolvedLayoutOptions()
        )
        cachedDisplayPacket = CachedDisplayPacket(
            prepared: prepared,
            layoutWidth: resolvedLayoutWidth,
            containerWidth: resolvedContainerWidth,
            layoutOptions: resolvedLayoutOptions(),
            packet: displayPacket
        )
        return displayPacket
    }

    private func resolvedLayoutOptions() -> PreparedTextLayoutOptions {
        var resolved = configuration.layoutOptions
        if resolved.layoutDirection == .natural {
            resolved.layoutDirection = effectiveUserInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
        }
        return resolved
    }

    private func visibleLinks() -> [AttributedLink] {
        let layoutWidth = resolvedDrawWidth()
        let containerWidth = bounds.width > 0 ? bounds.width : layoutWidth
        guard let packet = resolvedDisplayPacket(layoutWidth: layoutWidth, containerWidth: containerWidth) else {
            return resolvedInputText()?.links() ?? []
        }

        var links: [AttributedLink] = []
        var seenURLs = Set<URL>()
        for line in packet.lines {
            for link in line.attributedText.links() where seenURLs.insert(link.url).inserted {
                links.append(link)
            }
        }
        return links
    }

    private func activate(url: URL) -> Bool {
        if let linkTapHandler = configuration.linkTapHandler {
            linkTapHandler(url)
            return true
        }

        guard configuration.automaticallyOpensLinks else {
            return false
        }

        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }

    private func invalidateLayout() {
        cachedDisplayPacket = nil
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
        setNeedsLayout()
    }

    private func measurementEnv() -> MeasurementEnv {
        MeasurementEnv(
            scale: Double(window?.screen.scale ?? traitCollection.displayScale),
            contentSizeCategory: traitCollection.preferredContentSizeCategory.rawValue,
            localeIdentifier: Locale.current.identifier,
            measurementOptions: configuration.measurementOptions
        )
    }

    private func updateAccessibilityMetadata() {
        accessibilityLabel = resolvedInputText()?.string
        accessibilityValue = nil
        accessibilityHint = nil
        accessibilityCustomActions = nil
        accessibilityTraits.insert(.staticText)
        accessibilityTraits.remove(.link)

        guard let attributedText = resolvedInputText(), attributedText.length > 0 else {
            accessibilityAttributedLabel = nil
            return
        }

        accessibilityAttributedLabel = attributedText

        let links = visibleLinks()
        guard !links.isEmpty else {
            return
        }

        if links.count == 1, links[0].range == NSRange(location: 0, length: attributedText.length) {
            accessibilityTraits.insert(.link)
        } else {
            accessibilityHint = "Contains links"
        }

        accessibilityCustomActions = links.map { link in
            let actionTitle = link.title.isEmpty ? link.url.absoluteString : link.title
            return UIAccessibilityCustomAction(name: actionTitle) { [weak self] _ in
                self?.activate(url: link.url) ?? false
            }
        }
    }

    private func updateConfiguration(_ mutate: (inout PreparedLabelConfiguration) -> Void) {
        mutate(&configuration)
        let layoutSnapshot = configuration.layoutSnapshot()
        let accessibilitySnapshot = configuration.accessibilitySnapshot()
        let needsAccessibilityRefresh = lastAppliedAccessibilitySnapshot != accessibilitySnapshot
        let needsLayoutInvalidation = lastAppliedLayoutSnapshot != layoutSnapshot
        lastAppliedLayoutSnapshot = layoutSnapshot
        lastAppliedAccessibilitySnapshot = accessibilitySnapshot
        if needsAccessibilityRefresh {
            updateAccessibilityMetadata()
        }
        if needsLayoutInvalidation {
            invalidateLayout()
        }
    }

    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }

        _ = activateLink(at: gesture.location(in: self))
    }
}

private struct PreparedLabelLayoutSnapshot: Equatable {
    var preparedText: PreparedText?
    var attributedText: NSAttributedString?
    var sourceID: PreparedTextSourceID?
    var whiteSpaceMode: WhiteSpaceMode
    var lineHeightOverride: CGFloat?
    var measurementOptions: PreparedTextMeasurementOptions
    var maxLayoutWidth: CGFloat?
    var layoutOptions: PreparedTextLayoutOptions

    init(configuration: PreparedLabelConfiguration) {
        preparedText = configuration.preparedText
        attributedText = configuration.attributedText.map { NSAttributedString(attributedString: $0) }
        sourceID = configuration.sourceID
        whiteSpaceMode = configuration.whiteSpaceMode
        lineHeightOverride = configuration.lineHeightOverride
        measurementOptions = configuration.measurementOptions
        maxLayoutWidth = configuration.maxLayoutWidth
        layoutOptions = configuration.layoutOptions
    }

    static func == (lhs: PreparedLabelLayoutSnapshot, rhs: PreparedLabelLayoutSnapshot) -> Bool {
        lhs.preparedText == rhs.preparedText &&
            attributedTextMatches(lhs.attributedText, rhs.attributedText) &&
            lhs.sourceID == rhs.sourceID &&
            lhs.whiteSpaceMode == rhs.whiteSpaceMode &&
            lhs.lineHeightOverride == rhs.lineHeightOverride &&
            lhs.measurementOptions == rhs.measurementOptions &&
            lhs.maxLayoutWidth == rhs.maxLayoutWidth &&
            lhs.layoutOptions == rhs.layoutOptions
    }

    private static func attributedTextMatches(_ lhs: NSAttributedString?, _ rhs: NSAttributedString?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.isEqual(to: rhs)
        default:
            return false
        }
    }
}

private struct PreparedLabelAccessibilitySnapshot: Equatable {
    var layout: PreparedLabelLayoutSnapshot
    var automaticallyOpensLinks: Bool
    var hasLinkTapHandler: Bool

    init(configuration: PreparedLabelConfiguration) {
        layout = configuration.layoutSnapshot()
        automaticallyOpensLinks = configuration.automaticallyOpensLinks
        hasLinkTapHandler = configuration.linkTapHandler != nil
    }
}

private struct CachedDisplayPacket {
    var prepared: PreparedText
    var layoutWidth: CGFloat
    var containerWidth: CGFloat
    var layoutOptions: PreparedTextLayoutOptions
    var packet: PreparedTextDisplayPacket

    func matches(
        prepared: PreparedText,
        layoutWidth: CGFloat,
        containerWidth: CGFloat,
        layoutOptions: PreparedTextLayoutOptions
    ) -> Bool {
        self.prepared == prepared &&
            self.layoutWidth == layoutWidth &&
            self.containerWidth == containerWidth &&
            self.layoutOptions == layoutOptions
    }
}

private struct AttributedLink {
    var range: NSRange
    var url: URL
    var title: String
}

public struct PreparedTextUIKitExampleItem: Hashable {
    public var title: String
    public var body: NSAttributedString

    public init(title: String, body: NSAttributedString) {
        self.title = title
        self.body = body
    }

    public static func == (lhs: PreparedTextUIKitExampleItem, rhs: PreparedTextUIKitExampleItem) -> Bool {
        lhs.title == rhs.title && lhs.body.isEqual(to: rhs.body)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(body.string)
    }
}

private extension NSAttributedString {
    func links() -> [AttributedLink] {
        links(in: NSRange(location: 0, length: length))
    }

    func links(in range: NSRange) -> [AttributedLink] {
        guard length > 0 else {
            return []
        }
        let clampedStart = max(range.location, 0)
        let clampedEnd = min(NSMaxRange(range), length)
        guard clampedEnd > clampedStart else {
            return []
        }

        var links: [AttributedLink] = []
        enumerateAttribute(.link, in: NSRange(location: clampedStart, length: clampedEnd - clampedStart), options: []) { value, range, _ in
            if let url = Self.resolvedLinkURL(from: value) {
                let title = attributedSubstring(from: range).string
                links.append(AttributedLink(range: range, url: url, title: title))
            }
        }
        return links
    }

    func linkURL(at index: Int) -> URL? {
        guard index >= 0, index < length else {
            return nil
        }
        return Self.resolvedLinkURL(from: attribute(.link, at: index, effectiveRange: nil))
    }

    private static func resolvedLinkURL(from value: Any?) -> URL? {
        switch value {
        case let url as URL:
            return url
        case let string as String:
            return URL(string: string)
        case let nsString as NSString:
            return URL(string: nsString as String)
        default:
            return nil
        }
    }
}

private extension PreparedTextLineBreakMode {
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

private extension PreparedTextHorizontalAlignment {
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
