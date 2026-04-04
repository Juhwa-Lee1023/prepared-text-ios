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
    public var numberOfLines: Int
    public var lineBreakMode: NSLineBreakMode
    public var textAlignment: NSTextAlignment?
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
        self.numberOfLines = max(numberOfLines, 0)
        self.lineBreakMode = lineBreakMode
        self.textAlignment = textAlignment
        self.automaticallyOpensLinks = automaticallyOpensLinks
        self.linkTapHandler = linkTapHandler
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

    private func resolvedDisplayPacket(layoutWidth: CGFloat, containerWidth: CGFloat) -> PreparedDisplayPacket? {
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
               numberOfLines: configuration.numberOfLines,
               lineBreakMode: configuration.lineBreakMode,
               textAlignment: configuration.textAlignment
           ) {
            return cachedDisplayPacket.packet
        }

        guard let layoutPacket = resolvedLayoutPacket(width: resolvedLayoutWidth) else {
            return nil
        }

        let displayPacket = buildDisplayPacket(
            prepared: prepared,
            layoutPacket: layoutPacket,
            layoutWidth: resolvedLayoutWidth,
            containerWidth: resolvedContainerWidth
        )
        cachedDisplayPacket = CachedDisplayPacket(
            prepared: prepared,
            layoutWidth: resolvedLayoutWidth,
            containerWidth: resolvedContainerWidth,
            numberOfLines: configuration.numberOfLines,
            lineBreakMode: configuration.lineBreakMode,
            textAlignment: configuration.textAlignment,
            packet: displayPacket
        )
        return displayPacket
    }

    private func buildDisplayPacket(
        prepared: PreparedText,
        layoutPacket: PreparedLayoutPacket,
        layoutWidth: CGFloat,
        containerWidth: CGFloat
    ) -> PreparedDisplayPacket {
        let visibleLineCount = configuration.numberOfLines > 0
            ? min(configuration.numberOfLines, layoutPacket.lines.count)
            : layoutPacket.lines.count

        guard visibleLineCount > 0 else {
            return PreparedDisplayPacket(
                result: LayoutResult(fragments: [], height: 0, maxPaintWidth: 0),
                lines: []
            )
        }

        let isClipped = visibleLineCount < layoutPacket.lines.count
        var lines: [PreparedDisplayLine] = []
        lines.reserveCapacity(visibleLineCount)

        for index in 0..<visibleLineCount {
            let sourceLine = layoutPacket.lines[index]
            if isClipped, index == visibleLineCount - 1 {
                lines.append(
                    makeFinalDisplayLine(
                        prepared: prepared,
                        sourceLine: sourceLine,
                        layoutWidth: layoutWidth,
                        containerWidth: containerWidth
                    )
                )
            } else {
                lines.append(makeDisplayLine(from: sourceLine, containerWidth: containerWidth))
            }
        }

        let result = LayoutResult(
            fragments: lines.map(\.fragment),
            height: lines.reduce(0) { $0 + $1.fragment.blockAdvance },
            maxPaintWidth: lines.map(\.lineWidth).max() ?? 0
        )
        return PreparedDisplayPacket(result: result, lines: lines)
    }

    private func makeDisplayLine(from sourceLine: PreparedDrawLine, containerWidth: CGFloat) -> PreparedDisplayLine {
        let alignment = resolvedAlignment(for: sourceLine.attributedText)
        let originX = horizontalOrigin(
            alignment: alignment,
            lineWidth: sourceLine.fragment.paintWidth,
            containerWidth: containerWidth
        )
        return PreparedDisplayLine(
            fragment: sourceLine.fragment,
            attributedText: sourceLine.attributedText,
            ctLine: sourceLine.ctLine,
            lineWidth: sourceLine.fragment.paintWidth,
            originX: originX,
            isTruncated: false,
            visibleRange: NSRange(location: 0, length: sourceLine.attributedText.length)
        )
    }

    private func makeFinalDisplayLine(
        prepared: PreparedText,
        sourceLine: PreparedDrawLine,
        layoutWidth: CGFloat,
        containerWidth: CGFloat
    ) -> PreparedDisplayLine {
        switch configuration.lineBreakMode {
        case .byWordWrapping, .byCharWrapping:
            return makeDisplayLine(from: sourceLine, containerWidth: containerWidth)
        default:
            break
        }

        let remainder = textSystem.attributedText(
            prepared,
            from: sourceLine.fragment.start,
            to: nil,
            flatteningHardBreaks: false
        )
        guard remainder.length > 0 else {
            return makeDisplayLine(from: sourceLine, containerWidth: containerWidth)
        }

        let truncationSource = truncationSourceText(from: remainder)
        let truncation = truncationConfiguration(
            for: configuration.lineBreakMode,
            attributes: truncationTokenAttributes(sourceLine: sourceLine, remainder: truncationSource)
        )
        let renderedLine = renderedTruncatedLine(
            source: truncationSource,
            width: layoutWidth,
            mode: configuration.lineBreakMode,
            truncationType: truncation.type,
            token: truncation.token,
            forceTokenWhenFits: truncationSource.length < remainder.length
        )

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let measuredWidth = CGFloat(CTLineGetTypographicBounds(renderedLine.ctLine, &ascent, &descent, &leading))
        var fragment = sourceLine.fragment
        fragment.fitWidth = min(layoutWidth, measuredWidth)
        fragment.paintWidth = min(layoutWidth, measuredWidth)
        fragment.trailingWhitespaceWidth = 0
        fragment.ascent = max(fragment.ascent, ascent)
        fragment.descent = max(fragment.descent, descent)
        fragment.leading = max(fragment.leading, leading)

        let alignment = resolvedAlignment(for: renderedLine.attributedText)
        let originX = horizontalOrigin(
            alignment: alignment,
            lineWidth: fragment.paintWidth,
            containerWidth: containerWidth
        )

        return PreparedDisplayLine(
            fragment: fragment,
            attributedText: renderedLine.attributedText,
            ctLine: renderedLine.ctLine,
            lineWidth: fragment.paintWidth,
            originX: originX,
            isTruncated: true,
            visibleRange: renderedLine.visibleRange
        )
    }

    private func truncationSourceText(from remainder: NSAttributedString) -> NSAttributedString {
        let string = remainder.string as NSString
        let hardBreakRange = string.rangeOfCharacter(from: .newlines)
        guard hardBreakRange.location != NSNotFound else {
            return remainder
        }

        let prefixRange = NSRange(location: 0, length: hardBreakRange.location)
        guard prefixRange.length > 0 else {
            return NSAttributedString(string: "")
        }

        return remainder.attributedSubstring(from: prefixRange)
    }

    private func renderedTruncatedLine(
        source: NSAttributedString,
        width: CGFloat,
        mode: NSLineBreakMode,
        truncationType: CTLineTruncationType,
        token: NSAttributedString?,
        forceTokenWhenFits: Bool
    ) -> (attributedText: NSAttributedString, ctLine: CTLine, visibleRange: NSRange) {
        let baseLine = CTLineCreateWithAttributedString(source as CFAttributedString)
        let tokenLine = token.map { CTLineCreateWithAttributedString($0 as CFAttributedString) }
        let maybeTruncated = CTLineCreateTruncatedLine(baseLine, Double(width), truncationType, tokenLine)

        if let maybeTruncated {
            let visibleRange = nsRange(for: CTLineGetStringRange(maybeTruncated))
            let consumedAllSource = NSMaxRange(visibleRange) >= source.length
            if !forceTokenWhenFits || token == nil || token?.length == 0 || !consumedAllSource {
                return (source, maybeTruncated, visibleRange)
            }
        }

        guard forceTokenWhenFits, let token, token.length > 0 else {
            let ctLine = maybeTruncated ?? baseLine
            return (source, ctLine, nsRange(for: CTLineGetStringRange(ctLine)))
        }

        let forcedText = forceTruncationToken(on: source, token: token, mode: mode, width: width)
        let forcedLine = CTLineCreateWithAttributedString(forcedText as CFAttributedString)
        return (
            forcedText,
            forcedLine,
            NSRange(location: 0, length: forcedText.length)
        )
    }

    private func forceTruncationToken(
        on source: NSAttributedString,
        token: NSAttributedString,
        mode: NSLineBreakMode,
        width: CGFloat
    ) -> NSAttributedString {
        switch mode {
        case .byTruncatingHead:
            return longestFittingSuffix(source: source, token: token, width: width)
        case .byTruncatingMiddle:
            return longestFittingMiddle(source: source, token: token, width: width)
        case .byTruncatingTail:
            return longestFittingPrefix(source: source, token: token, width: width)
        case .byClipping, .byWordWrapping, .byCharWrapping:
            return source
        @unknown default:
            return longestFittingPrefix(source: source, token: token, width: width)
        }
    }

    private func longestFittingPrefix(source: NSAttributedString, token: NSAttributedString, width: CGFloat) -> NSAttributedString {
        let tokenOnly = token
        if lineWidth(for: tokenOnly) > width {
            return NSAttributedString(string: "")
        }

        var low = 0
        var high = source.length
        var best = 0
        while low <= high {
            let mid = (low + high) / 2
            let candidate = NSMutableAttributedString(attributedString: source.attributedSubstring(from: NSRange(location: 0, length: mid)))
            candidate.append(token)
            if lineWidth(for: candidate) <= width {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let result = NSMutableAttributedString(attributedString: source.attributedSubstring(from: NSRange(location: 0, length: best)))
        result.append(token)
        return result
    }

    private func longestFittingSuffix(source: NSAttributedString, token: NSAttributedString, width: CGFloat) -> NSAttributedString {
        if lineWidth(for: token) > width {
            return NSAttributedString(string: "")
        }

        var low = 0
        var high = source.length
        var best = 0
        while low <= high {
            let mid = (low + high) / 2
            let start = max(source.length - mid, 0)
            let candidate = NSMutableAttributedString(attributedString: token)
            candidate.append(source.attributedSubstring(from: NSRange(location: start, length: mid)))
            if lineWidth(for: candidate) <= width {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let start = max(source.length - best, 0)
        let result = NSMutableAttributedString(attributedString: token)
        result.append(source.attributedSubstring(from: NSRange(location: start, length: best)))
        return result
    }

    private func longestFittingMiddle(source: NSAttributedString, token: NSAttributedString, width: CGFloat) -> NSAttributedString {
        if lineWidth(for: token) > width {
            return NSAttributedString(string: "")
        }

        var low = 0
        var high = source.length
        var best = 0
        while low <= high {
            let keptCount = (low + high) / 2
            let candidate = middleTruncationCandidate(source: source, token: token, keptCount: keptCount)
            if lineWidth(for: candidate) <= width {
                best = keptCount
                low = keptCount + 1
            } else {
                high = keptCount - 1
            }
        }

        return middleTruncationCandidate(source: source, token: token, keptCount: best)
    }

    private func middleTruncationCandidate(source: NSAttributedString, token: NSAttributedString, keptCount: Int) -> NSAttributedString {
        let clamped = max(min(keptCount, source.length), 0)
        let frontCount = (clamped + 1) / 2
        let backCount = clamped - frontCount
        let result = NSMutableAttributedString()
        if frontCount > 0 {
            result.append(source.attributedSubstring(from: NSRange(location: 0, length: frontCount)))
        }
        result.append(token)
        if backCount > 0 {
            let start = max(source.length - backCount, 0)
            result.append(source.attributedSubstring(from: NSRange(location: start, length: backCount)))
        }
        return result
    }

    private func lineWidth(for attributedText: NSAttributedString) -> CGFloat {
        let line = CTLineCreateWithAttributedString(attributedText as CFAttributedString)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private func nsRange(for range: CFRange) -> NSRange {
        NSRange(location: max(range.location, 0), length: max(range.length, 0))
    }

    private func truncationConfiguration(
        for mode: NSLineBreakMode,
        attributes: [NSAttributedString.Key: Any]
    ) -> (type: CTLineTruncationType, token: NSAttributedString?) {
        switch mode {
        case .byTruncatingHead:
            return (.start, NSAttributedString(string: "…", attributes: attributes))
        case .byTruncatingMiddle:
            return (.middle, NSAttributedString(string: "…", attributes: attributes))
        case .byWordWrapping, .byCharWrapping, .byClipping:
            return (.end, NSAttributedString(string: "", attributes: attributes))
        case .byTruncatingTail:
            return (.end, NSAttributedString(string: "…", attributes: attributes))
        @unknown default:
            return (.end, NSAttributedString(string: "…", attributes: attributes))
        }
    }

    private func truncationTokenAttributes(
        sourceLine: PreparedDrawLine,
        remainder: NSAttributedString
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any]
        if sourceLine.attributedText.length > 0 {
            attributes = sourceLine.attributedText.attributes(
                at: sourceLine.attributedText.length - 1,
                effectiveRange: nil
            )
        } else if remainder.length > 0 {
            attributes = remainder.attributes(at: remainder.length - 1, effectiveRange: nil)
        } else {
            attributes = [:]
        }

        attributes[.link] = nil
        return attributes
    }

    private func resolvedAlignment(for attributedText: NSAttributedString) -> NSTextAlignment {
        if let explicitAlignment = configuration.textAlignment {
            return resolvedNaturalAlignment(for: explicitAlignment, attributedText: attributedText)
        }

        let paragraphAlignment = (attributedText.length > 0
            ? (attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment
            : nil) ?? .natural
        return resolvedNaturalAlignment(for: paragraphAlignment, attributedText: attributedText)
    }

    private func resolvedNaturalAlignment(for alignment: NSTextAlignment, attributedText: NSAttributedString) -> NSTextAlignment {
        switch alignment {
        case .left, .center, .right:
            return alignment
        case .natural, .justified:
            let baseDirection = (attributedText.length > 0
                ? (attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.baseWritingDirection
                : nil) ?? .natural
            switch baseDirection {
            case .rightToLeft:
                return .right
            case .leftToRight:
                return .left
            default:
                return effectiveUserInterfaceLayoutDirection == .rightToLeft ? .right : .left
            }
        @unknown default:
            return effectiveUserInterfaceLayoutDirection == .rightToLeft ? .right : .left
        }
    }

    private func horizontalOrigin(alignment: NSTextAlignment, lineWidth: CGFloat, containerWidth: CGFloat) -> CGFloat {
        switch alignment {
        case .center:
            return max((containerWidth - lineWidth) / 2, 0)
        case .right:
            return max(containerWidth - lineWidth, 0)
        case .left, .natural, .justified:
            return 0
        @unknown default:
            return 0
        }
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
            for link in line.visibleLinks() where seenURLs.insert(link.url).inserted {
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

private struct PreparedDisplayLine {
    var fragment: LineFragment
    var attributedText: NSAttributedString
    var ctLine: CTLine
    var lineWidth: CGFloat
    var originX: CGFloat
    var isTruncated: Bool
    var visibleRange: NSRange

    func frame(originY: CGFloat) -> CGRect {
        let typographicTop = originY + fragment.paragraphSpacingBefore
        let typographicHeight = max(fragment.ascent + fragment.descent + fragment.leading, 1)
        return CGRect(x: originX, y: typographicTop, width: lineWidth, height: typographicHeight)
    }

    func visibleLinks() -> [AttributedLink] {
        attributedText.links(in: visibleRange)
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
    var numberOfLines: Int
    var lineBreakMode: NSLineBreakMode
    var textAlignment: NSTextAlignment?

    init(configuration: PreparedLabelConfiguration) {
        preparedText = configuration.preparedText
        attributedText = configuration.attributedText.map { NSAttributedString(attributedString: $0) }
        sourceID = configuration.sourceID
        whiteSpaceMode = configuration.whiteSpaceMode
        lineHeightOverride = configuration.lineHeightOverride
        measurementOptions = configuration.measurementOptions
        maxLayoutWidth = configuration.maxLayoutWidth
        numberOfLines = configuration.numberOfLines
        lineBreakMode = configuration.lineBreakMode
        textAlignment = configuration.textAlignment
    }

    static func == (lhs: PreparedLabelLayoutSnapshot, rhs: PreparedLabelLayoutSnapshot) -> Bool {
        lhs.preparedText == rhs.preparedText &&
            attributedTextMatches(lhs.attributedText, rhs.attributedText) &&
            lhs.sourceID == rhs.sourceID &&
            lhs.whiteSpaceMode == rhs.whiteSpaceMode &&
            lhs.lineHeightOverride == rhs.lineHeightOverride &&
            lhs.measurementOptions == rhs.measurementOptions &&
            lhs.maxLayoutWidth == rhs.maxLayoutWidth &&
            lhs.numberOfLines == rhs.numberOfLines &&
            lhs.lineBreakMode == rhs.lineBreakMode &&
            lhs.textAlignment == rhs.textAlignment
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

private struct PreparedDisplayPacket {
    var result: LayoutResult
    var lines: [PreparedDisplayLine]
}

private struct CachedDisplayPacket {
    var prepared: PreparedText
    var layoutWidth: CGFloat
    var containerWidth: CGFloat
    var numberOfLines: Int
    var lineBreakMode: NSLineBreakMode
    var textAlignment: NSTextAlignment?
    var packet: PreparedDisplayPacket

    func matches(
        prepared: PreparedText,
        layoutWidth: CGFloat,
        containerWidth: CGFloat,
        numberOfLines: Int,
        lineBreakMode: NSLineBreakMode,
        textAlignment: NSTextAlignment?
    ) -> Bool {
        self.prepared == prepared &&
            self.layoutWidth == layoutWidth &&
            self.containerWidth == containerWidth &&
            self.numberOfLines == numberOfLines &&
            self.lineBreakMode == lineBreakMode &&
            self.textAlignment == textAlignment
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
#endif
