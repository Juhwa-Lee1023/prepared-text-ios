#if canImport(UIKit) && !os(macOS)
import CoreText
import PretextCore
import UIKit

private enum PreparedObstacleDemoPalette {
    static func dynamic(_ light: UIColor, _ dark: UIColor) -> UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }

    static let surfaceFill = dynamic(
        UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0),
        UIColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)
    )
    static let surfaceStroke = dynamic(
        UIColor.black.withAlphaComponent(0.08),
        UIColor.white.withAlphaComponent(0.12)
    )
    static let guideEven = dynamic(
        UIColor.black.withAlphaComponent(0.05),
        UIColor.white.withAlphaComponent(0.05)
    )
    static let guideOdd = dynamic(
        UIColor.black.withAlphaComponent(0.025),
        UIColor.white.withAlphaComponent(0.025)
    )
}

public struct PreparedTextObstacleCircle: Hashable {
    public var center: CGPoint
    public var radius: CGFloat

    public init(center: CGPoint, radius: CGFloat) {
        self.center = center
        self.radius = radius
    }
}

public enum PreparedTextObstacleDemoMode: Hashable {
    case dragonOrbit
    case bouncingBalls
    case touchTrail
    case fixed([PreparedTextObstacleCircle])
}

public struct PreparedTextObstacleDebugSnapshot: Hashable {
    public var obstacleCount: Int
    public var rowCount: Int
    public var fragmentCount: Int
    public var splitRowCount: Int
    public var renderedStrings: [String]

    public init(
        obstacleCount: Int,
        rowCount: Int,
        fragmentCount: Int,
        splitRowCount: Int,
        renderedStrings: [String]
    ) {
        self.obstacleCount = obstacleCount
        self.rowCount = rowCount
        self.fragmentCount = fragmentCount
        self.splitRowCount = splitRowCount
        self.renderedStrings = renderedStrings
    }
}

public struct PreparedTextObstacleDemoConfiguration {
    public var attributedText: NSAttributedString
    public var sourceID: PreparedTextSourceID?
    public var whiteSpaceMode: WhiteSpaceMode
    public var lineHeightOverride: CGFloat?
    public var mode: PreparedTextObstacleDemoMode
    public var contentInsets: UIEdgeInsets
    public var obstacleRadius: CGFloat
    public var obstaclePadding: CGFloat
    public var preferredHeight: CGFloat
    public var trailLifetime: CFTimeInterval
    public var minimumSpanWidth: CGFloat
    public var orbitSpeedMultiplier: CGFloat

    public init(
        attributedText: NSAttributedString,
        sourceID: PreparedTextSourceID? = nil,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        lineHeightOverride: CGFloat? = nil,
        mode: PreparedTextObstacleDemoMode = .dragonOrbit,
        contentInsets: UIEdgeInsets = UIEdgeInsets(top: 28, left: 24, bottom: 28, right: 24),
        obstacleRadius: CGFloat = 42,
        obstaclePadding: CGFloat = 12,
        preferredHeight: CGFloat = 280,
        trailLifetime: CFTimeInterval = 0.55,
        minimumSpanWidth: CGFloat = 30,
        orbitSpeedMultiplier: CGFloat = 1
    ) {
        self.attributedText = attributedText
        self.sourceID = sourceID
        self.whiteSpaceMode = whiteSpaceMode
        self.lineHeightOverride = lineHeightOverride
        self.mode = mode
        self.contentInsets = contentInsets
        self.obstacleRadius = obstacleRadius
        self.obstaclePadding = obstaclePadding
        self.preferredHeight = preferredHeight
        self.trailLifetime = trailLifetime
        self.minimumSpanWidth = minimumSpanWidth
        self.orbitSpeedMultiplier = max(orbitSpeedMultiplier, 0.1)
    }
}

public final class PreparedTextObstacleDemoView: UIView {
    public var textSystem: PreparedTextSystem
    public private(set) var configuration: PreparedTextObstacleDemoConfiguration

    private var cachedPreparedText: PreparedText?
    private var cachedPreparationFingerprint: PreparationFingerprint?
    private var orbitStartTime = CACurrentMediaTime()
    private var touchTrail: [TrailPoint] = []
    private var displayLink: CADisplayLink?
    private lazy var panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))

    public override init(frame: CGRect) {
        self.textSystem = .shared
        self.configuration = PreparedTextObstacleDemoView.defaultConfiguration()
        super.init(frame: frame)
        configureView()
    }

    public required init?(coder: NSCoder) {
        self.textSystem = .shared
        self.configuration = PreparedTextObstacleDemoView.defaultConfiguration()
        super.init(coder: coder)
        configureView()
    }

    public func apply(configuration: PreparedTextObstacleDemoConfiguration) {
        let previousMode = self.configuration.mode
        let previousFingerprint = preparationFingerprint(for: self.configuration)
        let nextFingerprint = preparationFingerprint(for: configuration)

        self.configuration = configuration
        if previousFingerprint != nextFingerprint {
            cachedPreparedText = nil
            cachedPreparationFingerprint = nil
        }
        if previousMode != configuration.mode {
            touchTrail.removeAll()
            orbitStartTime = CACurrentMediaTime()
        }
        invalidateIntrinsicContentSize()
        updateGestureAvailability()
        updateDisplayLinkState()
        setNeedsDisplay()
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: configuration.preferredHeight)
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width.isFinite && size.width > 0 ? size.width : bounds.width
        return CGSize(width: width, height: configuration.preferredHeight)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDisplayLinkState()
    }

    public override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let plan = renderPlan(in: bounds)
        drawSurfaceChrome(in: bounds)
        drawGuides(for: plan)
        drawObstacles(plan.obstacles)
        drawText(plan, in: context)
    }

    public func debugLayoutSnapshot(in bounds: CGRect) -> PreparedTextObstacleDebugSnapshot {
        renderPlan(in: bounds).debugSnapshot
    }

    private func configureView() {
        isOpaque = false
        contentMode = .redraw
        clipsToBounds = true
        layer.cornerRadius = 30
        layer.cornerCurve = .continuous
        addGestureRecognizer(panGestureRecognizer)
        updateGestureAvailability()
        updateDisplayLinkState()
    }

    private func updateGestureAvailability() {
        panGestureRecognizer.isEnabled = {
            if case .touchTrail = configuration.mode {
                return true
            }
            return false
        }()
    }

    private func updateDisplayLinkState() {
        let shouldAnimate = window != nil && (isAnimatedObstacleMode || !touchTrail.isEmpty)
        if shouldAnimate {
            if displayLink == nil {
                let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
                displayLink.add(to: .main, forMode: .common)
                self.displayLink = displayLink
            }
        } else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    private var isAnimatedObstacleMode: Bool {
        switch configuration.mode {
        case .dragonOrbit, .bouncingBalls:
            return true
        case .touchTrail, .fixed:
            return false
        }
    }

    @objc private func handleDisplayLink(_ displayLink: CADisplayLink) {
        let now = displayLink.timestamp
        let previousCount = touchTrail.count
        touchTrail.removeAll { now - $0.timestamp > configuration.trailLifetime }
        if isAnimatedObstacleMode || previousCount != touchTrail.count || !touchTrail.isEmpty {
            setNeedsDisplay()
        }
        updateDisplayLinkState()
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard case .touchTrail = configuration.mode else {
            return
        }

        let point = clampToContentRect(gesture.location(in: self))
        let now = CACurrentMediaTime()

        switch gesture.state {
        case .began, .changed:
            if shouldAppendTrailPoint(point) {
                touchTrail.append(TrailPoint(center: point, timestamp: now))
            } else if let lastIndex = touchTrail.indices.last {
                touchTrail[lastIndex] = TrailPoint(center: point, timestamp: now)
            }
            setNeedsDisplay()
            updateDisplayLinkState()

        case .ended, .cancelled, .failed:
            touchTrail.append(TrailPoint(center: point, timestamp: now))
            setNeedsDisplay()
            updateDisplayLinkState()

        default:
            break
        }
    }

    private func shouldAppendTrailPoint(_ point: CGPoint) -> Bool {
        guard let lastPoint = touchTrail.last?.center else {
            return true
        }
        return hypot(lastPoint.x - point.x, lastPoint.y - point.y) >= 10
    }

    private func clampToContentRect(_ point: CGPoint) -> CGPoint {
        let rect = textRect(in: bounds)
        guard !rect.isNull, !rect.isEmpty else {
            return point
        }

        return CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func resolvedPreparedText() -> PreparedText? {
        let fingerprint = preparationFingerprint(for: configuration)
        if let cachedPreparedText, cachedPreparationFingerprint == fingerprint {
            return cachedPreparedText
        }

        let options = PreparedTextOptions(
            whiteSpaceMode: configuration.whiteSpaceMode,
            locale: Locale.current
        )
        let prepared: PreparedText
        if let sourceID = configuration.sourceID {
            prepared = textSystem.prepare(configuration.attributedText, sourceID: sourceID, options: options)
        } else {
            prepared = textSystem.prepare(configuration.attributedText, options: options)
        }
        cachedPreparedText = prepared
        cachedPreparationFingerprint = fingerprint
        return prepared
    }

    private func renderPlan(in bounds: CGRect) -> RenderPlan {
        let textRect = textRect(in: bounds)
        guard let prepared = resolvedPreparedText(), !textRect.isNull, textRect.width > 0 else {
            return RenderPlan(textRect: textRect, rowHeight: 0, obstacles: [], fragments: [], splitRowIndices: [], rowCount: 0)
        }

        let rowHeight = max(configuration.lineHeightOverride ?? prepared.defaultLineHeight, 1)
        let obstacles = resolvedObstacles(in: textRect)

        var cursor = LayoutCursor()
        var rowY = textRect.minY
        var rowIndex = 0
        var fragments: [RenderedFragment] = []
        var splitRowIndices = Set<Int>()

        layoutLoop: while rowY < textRect.maxY - 0.5 {
            let bandRect = CGRect(x: textRect.minX, y: rowY, width: textRect.width, height: rowHeight)
            let spans = availableSpans(in: bandRect, textRect: textRect, obstacles: obstacles)
            if spans.count > 1 {
                splitRowIndices.insert(rowIndex)
            }

            if spans.isEmpty {
                rowY += rowHeight
                rowIndex += 1
                continue
            }

            var rowProgressed = false
            var exhaustedText = false
            for span in spans {
                guard let line = textSystem.engine.nextLine(prepared, cursor: cursor, maxWidth: span.width) else {
                    exhaustedText = true
                    break
                }

                if line.end == cursor, line.paintEnd == line.start {
                    continue
                }

                let attributedLine = textSystem.engine.attributedLine(prepared, line: line)
                let ctLine = CTLineCreateWithAttributedString(attributedLine as CFAttributedString)
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                _ = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)

                fragments.append(
                    RenderedFragment(
                        rowIndex: rowIndex,
                        rowY: rowY,
                        originX: span.minX,
                        spanWidth: span.width,
                        attributedText: attributedLine,
                        ctLine: ctLine,
                        ascent: ascent,
                        descent: descent,
                        leading: leading,
                        plainText: line.text ?? attributedLine.string
                    )
                )
                let consumedHardBreak = lineConsumesHardBreak(line, in: prepared)
                cursor = line.end
                rowProgressed = true
                if consumedHardBreak {
                    break
                }
            }

            if !rowProgressed {
                break
            }

            rowY += rowHeight
            rowIndex += 1
            if exhaustedText {
                break layoutLoop
            }
        }

        return RenderPlan(
            textRect: textRect,
            rowHeight: rowHeight,
            obstacles: obstacles,
            fragments: fragments,
            splitRowIndices: splitRowIndices,
            rowCount: rowIndex
        )
    }

    private func textRect(in bounds: CGRect) -> CGRect {
        let rect = bounds.inset(by: configuration.contentInsets)
        if rect.width <= 0 || rect.height <= 0 {
            return .null
        }
        return rect
    }

    private func preparationFingerprint(for configuration: PreparedTextObstacleDemoConfiguration) -> PreparationFingerprint {
        PreparationFingerprint(
            attributedText: configuration.attributedText,
            sourceID: configuration.sourceID,
            whiteSpaceMode: configuration.whiteSpaceMode,
            localeIdentifier: Locale.current.identifier
        )
    }

    private func lineConsumesHardBreak(_ line: LineResult, in prepared: PreparedText) -> Bool {
        guard line.paintEnd < line.end else {
            return false
        }

        let trailingText = textSystem.attributedText(
            prepared,
            from: line.paintEnd,
            to: line.end,
            flatteningHardBreaks: false
        )
        return trailingText.string.rangeOfCharacter(from: .newlines) != nil
    }

    private func resolvedObstacles(in textRect: CGRect) -> [VisualObstacle] {
        switch configuration.mode {
        case .dragonOrbit:
            return orbitingSerpentObstacles(in: textRect)

        case .bouncingBalls:
            return bouncingBallObstacles(in: textRect)

        case .touchTrail:
            if touchTrail.isEmpty {
                return []
            }
            let now = CACurrentMediaTime()
            return touchTrail.enumerated().compactMap { index, point in
                let progress = max(0, 1 - ((now - point.timestamp) / configuration.trailLifetime))
                guard progress > 0 else {
                    return nil
                }
                let radius = configuration.obstacleRadius * (0.58 + progress * 0.42)
                let alpha = 0.16 + progress * 0.74
                return VisualObstacle(
                    circle: PreparedTextObstacleCircle(center: point.center, radius: radius),
                    alpha: alpha,
                    fillColor: UIColor(red: 0.21, green: 0.50, blue: 1.0, alpha: 1),
                    strokeColor: UIColor(red: 0.09, green: 0.20, blue: 0.54, alpha: 1),
                    kind: index == touchTrail.count - 1 ? .finger : .trail
                )
            }

        case let .fixed(circles):
            return circles.map {
                VisualObstacle(
                    circle: $0,
                    alpha: 1,
                    fillColor: UIColor(red: 0.29, green: 0.66, blue: 0.98, alpha: 1),
                    strokeColor: UIColor(red: 0.05, green: 0.22, blue: 0.54, alpha: 1),
                    kind: .trail
                )
            }
        }
    }

    private func orbitingCircle(in textRect: CGRect) -> PreparedTextObstacleCircle {
        let radius = configuration.obstacleRadius
        let padding = radius + configuration.obstaclePadding + 10
        let safeRect = textRect.insetBy(dx: padding, dy: padding)
        guard safeRect.width > 0, safeRect.height > 0 else {
            return PreparedTextObstacleCircle(center: CGPoint(x: textRect.midX, y: textRect.midY), radius: radius)
        }

        let t = (CACurrentMediaTime() - orbitStartTime) * CFTimeInterval(configuration.orbitSpeedMultiplier)
        let x = safeRect.midX + sin(t * 0.82) * safeRect.width * 0.42 + cos(t * 1.67) * safeRect.width * 0.08
        let y = safeRect.midY + cos(t * 0.71) * safeRect.height * 0.32 + sin(t * 1.19) * safeRect.height * 0.14
        return PreparedTextObstacleCircle(center: CGPoint(x: x, y: y), radius: radius)
    }

    private func orbitingSerpentObstacles(in textRect: CGRect) -> [VisualObstacle] {
        let head = orbitingCircle(in: textRect)
        let previous = orbitingCircle(
            in: textRect,
            timeOffset: -(0.08 / CFTimeInterval(configuration.orbitSpeedMultiplier))
        )
        let tangent = normalizedVector(from: previous.center, to: head.center)
        let normal = CGPoint(x: -tangent.y, y: tangent.x)
        let t = (CACurrentMediaTime() - orbitStartTime) * CFTimeInterval(configuration.orbitSpeedMultiplier)
        let fill = PreparedObstacleDemoPalette.dynamic(
            UIColor(red: 0.97, green: 0.57, blue: 0.25, alpha: 1),
            UIColor(red: 0.81, green: 0.42, blue: 0.16, alpha: 1)
        )
        let stroke = PreparedObstacleDemoPalette.dynamic(
            UIColor(red: 0.53, green: 0.16, blue: 0.04, alpha: 1),
            UIColor(red: 0.97, green: 0.77, blue: 0.47, alpha: 1)
        )

        return (0..<9).map { index in
            let progress = CGFloat(index) / 8
            let spacing = configuration.obstacleRadius * (0.95 + progress * 0.32)
            let baseCenter = CGPoint(
                x: head.center.x - tangent.x * spacing * CGFloat(index),
                y: head.center.y - tangent.y * spacing * CGFloat(index)
            )
            let wiggle = sin(t * 2.4 - Double(index) * 0.68) * Double(configuration.obstacleRadius) * (0.22 + Double(progress) * 0.36)
            let center = CGPoint(
                x: baseCenter.x + normal.x * wiggle,
                y: baseCenter.y + normal.y * wiggle
            )
            let radius = configuration.obstacleRadius * (1.04 - progress * 0.48)
            let kind: VisualObstacle.Kind
            if index == 0 {
                kind = .serpentHead
            } else if index == 8 {
                kind = .serpentTail
            } else {
                kind = .serpentBody
            }
            return VisualObstacle(
                circle: PreparedTextObstacleCircle(center: center, radius: radius),
                alpha: 1,
                fillColor: fill,
                strokeColor: stroke,
                kind: kind
            )
        }
    }

    private func bouncingBallObstacles(in textRect: CGRect) -> [VisualObstacle] {
        let count = 7
        let t = CGFloat((CACurrentMediaTime() - orbitStartTime) * CFTimeInterval(configuration.orbitSpeedMultiplier))
        let baseRadius = configuration.obstacleRadius * 0.48
        let inset = configuration.obstaclePadding + baseRadius + 8
        let safeRect = textRect.insetBy(dx: inset, dy: inset)

        guard safeRect.width > 0, safeRect.height > 0 else {
            return []
        }

        let fills: [UIColor] = [
            PreparedObstacleDemoPalette.dynamic(
                UIColor(red: 0.99, green: 0.42, blue: 0.31, alpha: 1),
                UIColor(red: 0.87, green: 0.35, blue: 0.26, alpha: 1)
            ),
            PreparedObstacleDemoPalette.dynamic(
                UIColor(red: 0.27, green: 0.67, blue: 0.98, alpha: 1),
                UIColor(red: 0.20, green: 0.53, blue: 0.86, alpha: 1)
            ),
            PreparedObstacleDemoPalette.dynamic(
                UIColor(red: 0.99, green: 0.74, blue: 0.25, alpha: 1),
                UIColor(red: 0.81, green: 0.58, blue: 0.18, alpha: 1)
            ),
            PreparedObstacleDemoPalette.dynamic(
                UIColor(red: 0.45, green: 0.82, blue: 0.47, alpha: 1),
                UIColor(red: 0.30, green: 0.66, blue: 0.33, alpha: 1)
            ),
        ]
        let stroke = PreparedObstacleDemoPalette.dynamic(
            UIColor(red: 0.10, green: 0.17, blue: 0.29, alpha: 1),
            UIColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 1)
        )

        return (0..<count).map { index in
            let progress = CGFloat(index) / CGFloat(max(count - 1, 1))
            let radius = baseRadius * (0.92 + (1 - progress) * 0.42)
            let playableRect = safeRect.insetBy(dx: radius, dy: radius)
            let phase = CGFloat(index) * 0.77

            let rawX = playableRect.minX + playableRect.width * pingPong01((t * (0.41 + progress * 0.34)) + phase * 1.31)
            let rawY = playableRect.minY + playableRect.height * pingPong01((t * (0.56 + progress * 0.29)) + phase * 0.93 + 0.18)
            let wobble = sin(Double(t * (1.7 + progress * 0.6) + phase)) * Double(baseRadius) * 0.12
            let center = CGPoint(
                x: min(max(rawX + CGFloat(wobble), playableRect.minX), playableRect.maxX),
                y: min(max(rawY - CGFloat(wobble * 0.55), playableRect.minY), playableRect.maxY)
            )

            return VisualObstacle(
                circle: PreparedTextObstacleCircle(center: center, radius: radius),
                alpha: 1,
                fillColor: fills[index % fills.count],
                strokeColor: stroke,
                kind: .orb
            )
        }
    }

    private func orbitingCircle(in textRect: CGRect, timeOffset: CFTimeInterval) -> PreparedTextObstacleCircle {
        let radius = configuration.obstacleRadius
        let padding = radius + configuration.obstaclePadding + 10
        let safeRect = textRect.insetBy(dx: padding, dy: padding)
        guard safeRect.width > 0, safeRect.height > 0 else {
            return PreparedTextObstacleCircle(center: CGPoint(x: textRect.midX, y: textRect.midY), radius: radius)
        }

        let t = (CACurrentMediaTime() - orbitStartTime + timeOffset) * CFTimeInterval(configuration.orbitSpeedMultiplier)
        let x = safeRect.midX + sin(t * 0.82) * safeRect.width * 0.42 + cos(t * 1.67) * safeRect.width * 0.08
        let y = safeRect.midY + cos(t * 0.71) * safeRect.height * 0.32 + sin(t * 1.19) * safeRect.height * 0.14
        return PreparedTextObstacleCircle(center: CGPoint(x: x, y: y), radius: radius)
    }

    private func availableSpans(in bandRect: CGRect, textRect: CGRect, obstacles: [VisualObstacle]) -> [HorizontalSpan] {
        guard bandRect.width > 0 else {
            return []
        }

        let intervals = mergedExclusionIntervals(in: bandRect, textRect: textRect, obstacles: obstacles)
        if intervals.isEmpty {
            return [HorizontalSpan(minX: textRect.minX, maxX: textRect.maxX)]
        }

        var spans: [HorizontalSpan] = []
        var currentMinX = textRect.minX

        for interval in intervals {
            if interval.minX - currentMinX >= configuration.minimumSpanWidth {
                spans.append(HorizontalSpan(minX: currentMinX, maxX: interval.minX))
            }
            currentMinX = max(currentMinX, interval.maxX)
        }

        if textRect.maxX - currentMinX >= configuration.minimumSpanWidth {
            spans.append(HorizontalSpan(minX: currentMinX, maxX: textRect.maxX))
        }

        return spans
    }

    private func mergedExclusionIntervals(in bandRect: CGRect, textRect: CGRect, obstacles: [VisualObstacle]) -> [HorizontalSpan] {
        let midY = bandRect.midY
        var intervals: [HorizontalSpan] = []

        for obstacle in obstacles {
            let layoutRadius = obstacle.circle.radius + configuration.obstaclePadding
            let distanceY = abs(midY - obstacle.circle.center.y)
            guard distanceY < layoutRadius else {
                continue
            }

            let deltaX = sqrt(max((layoutRadius * layoutRadius) - (distanceY * distanceY), 0))
            let minX = max(textRect.minX, obstacle.circle.center.x - deltaX)
            let maxX = min(textRect.maxX, obstacle.circle.center.x + deltaX)
            guard maxX - minX > 0 else {
                continue
            }
            intervals.append(HorizontalSpan(minX: minX, maxX: maxX))
        }

        let sorted = intervals.sorted { lhs, rhs in
            if lhs.minX == rhs.minX {
                return lhs.maxX < rhs.maxX
            }
            return lhs.minX < rhs.minX
        }

        var merged: [HorizontalSpan] = []
        for interval in sorted {
            guard var last = merged.popLast() else {
                merged.append(interval)
                continue
            }

            if interval.minX <= last.maxX + 4 {
                last.maxX = max(last.maxX, interval.maxX)
                merged.append(last)
            } else {
                merged.append(last)
                merged.append(interval)
            }
        }

        return merged
    }

    private func drawSurfaceChrome(in bounds: CGRect) {
        let cardRect = bounds.insetBy(dx: 1, dy: 1)
        let background = UIBezierPath(roundedRect: cardRect, cornerRadius: 30)
        PreparedObstacleDemoPalette.surfaceFill.setFill()
        background.fill()

        let border = UIBezierPath(roundedRect: cardRect, cornerRadius: 30)
        PreparedObstacleDemoPalette.surfaceStroke.setStroke()
        border.lineWidth = 1
        border.stroke()
    }

    private func drawGuides(for plan: RenderPlan) {
        guard plan.rowHeight > 0 else {
            return
        }

        var y = plan.textRect.minY
        var rowIndex = 0
        while y < plan.textRect.maxY - 0.5 {
            let bandRect = CGRect(x: plan.textRect.minX, y: y, width: plan.textRect.width, height: plan.rowHeight)
            let path = UIBezierPath(roundedRect: bandRect.insetBy(dx: 0, dy: 1.5), cornerRadius: 10)
            let fillColor = rowIndex.isMultiple(of: 2)
                ? PreparedObstacleDemoPalette.guideEven
                : PreparedObstacleDemoPalette.guideOdd
            fillColor.setFill()
            path.fill()
            y += plan.rowHeight
            rowIndex += 1
        }
    }

    private func drawObstacles(_ obstacles: [VisualObstacle]) {
        for obstacle in obstacles {
            let circleRect = CGRect(
                x: obstacle.circle.center.x - obstacle.circle.radius,
                y: obstacle.circle.center.y - obstacle.circle.radius,
                width: obstacle.circle.radius * 2,
                height: obstacle.circle.radius * 2
            )

            let shadowRect = circleRect.insetBy(dx: -6, dy: -6)
            let shadowPath = UIBezierPath(ovalIn: shadowRect)
            obstacle.fillColor.withAlphaComponent(0.08 * obstacle.alpha).setFill()
            shadowPath.fill()

            let fillPath = UIBezierPath(ovalIn: circleRect)
            obstacle.fillColor.withAlphaComponent(0.78 * obstacle.alpha).setFill()
            fillPath.fill()
            obstacle.strokeColor.withAlphaComponent(0.9 * obstacle.alpha).setStroke()
            fillPath.lineWidth = 2
            fillPath.stroke()

            drawSerpentAdornment(for: obstacle, in: circleRect)
            drawObstacleGlyph(obstacle, in: circleRect)
        }
    }

    private func drawSerpentAdornment(for obstacle: VisualObstacle, in rect: CGRect) {
        switch obstacle.kind {
        case .serpentHead:
            let eyeDiameter = max(rect.width * 0.08, 3)
            let eyeY = rect.minY + rect.height * 0.34
            UIColor.white.withAlphaComponent(0.95).setFill()
            UIBezierPath(ovalIn: CGRect(x: rect.midX - rect.width * 0.18, y: eyeY, width: eyeDiameter, height: eyeDiameter)).fill()
            UIBezierPath(ovalIn: CGRect(x: rect.midX + rect.width * 0.06, y: eyeY, width: eyeDiameter, height: eyeDiameter)).fill()

            let hornPath = UIBezierPath()
            hornPath.move(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.18))
            hornPath.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY - rect.height * 0.10))
            hornPath.move(to: CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.minY + rect.height * 0.18))
            hornPath.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY - rect.height * 0.10))
            obstacle.strokeColor.withAlphaComponent(0.9).setStroke()
            hornPath.lineWidth = 2
            hornPath.lineCapStyle = .round
            hornPath.stroke()

        case .serpentTail:
            let tailPath = UIBezierPath()
            tailPath.move(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.midY))
            tailPath.addLine(to: CGPoint(x: rect.maxX + rect.width * 0.22, y: rect.midY - rect.height * 0.14))
            tailPath.addLine(to: CGPoint(x: rect.maxX + rect.width * 0.18, y: rect.midY + rect.height * 0.16))
            tailPath.close()
            obstacle.fillColor.withAlphaComponent(0.72).setFill()
            tailPath.fill()
            obstacle.strokeColor.withAlphaComponent(0.85).setStroke()
            tailPath.lineWidth = 2
            tailPath.stroke()

        case .serpentBody, .finger, .trail, .orb:
            break
        }
    }

    private func drawObstacleGlyph(_ obstacle: VisualObstacle, in rect: CGRect) {
        let text: String
        let foregroundColor: UIColor

        switch obstacle.kind {
        case .serpentHead, .serpentBody, .serpentTail:
            text = ""
            foregroundColor = .clear
        case .orb:
            text = ""
            foregroundColor = .clear
        case .finger:
            text = "DRAG"
            foregroundColor = UIColor.white
        case .trail:
            text = ""
            foregroundColor = .clear
        }

        guard !text.isEmpty else {
            return
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: foregroundColor.withAlphaComponent(obstacle.alpha),
            .paragraphStyle: paragraphStyle,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
        let drawRect = CGRect(
            x: rect.midX - (size.width / 2),
            y: rect.midY - (size.height / 2),
            width: ceil(size.width),
            height: ceil(size.height)
        )
        attributed.draw(in: drawRect)
    }

    private func drawText(_ plan: RenderPlan, in context: CGContext) {
        guard !plan.fragments.isEmpty else {
            return
        }

        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)

        for fragment in plan.fragments {
            let slack = max(plan.rowHeight - (fragment.ascent + fragment.descent), 0)
            let baselineFromTop = fragment.rowY + fragment.ascent + (slack * 0.35)
            context.textPosition = CGPoint(
                x: fragment.originX,
                y: bounds.height - baselineFromTop
            )
            CTLineDraw(fragment.ctLine, context)
        }

        context.restoreGState()
    }

    public static func defaultConfiguration() -> PreparedTextObstacleDemoConfiguration {
        PreparedTextObstacleDemoConfiguration(
            attributedText: NSAttributedString(
                string: "Prepared text can already prepare immutable attributed content once and then answer hot-path line breaking questions quickly. This demo layers obstacle-aware width proposals on top so a moving object or a finger trail can temporarily carve holes into the surface while the text keeps flowing around it.",
                attributes: [.font: UIFont.systemFont(ofSize: 17, weight: .regular)]
            ),
            sourceID: PreparedTextSourceID("obstacle-demo-default")
        )
    }
}

private struct TrailPoint {
    var center: CGPoint
    var timestamp: CFTimeInterval
}

private struct PreparationFingerprint: Equatable {
    var attributedText: NSAttributedString
    var sourceID: PreparedTextSourceID?
    var whiteSpaceMode: WhiteSpaceMode
    var localeIdentifier: String?

    static func == (lhs: PreparationFingerprint, rhs: PreparationFingerprint) -> Bool {
        lhs.sourceID == rhs.sourceID &&
            lhs.whiteSpaceMode == rhs.whiteSpaceMode &&
            lhs.localeIdentifier == rhs.localeIdentifier &&
            lhs.attributedText.isEqual(to: rhs.attributedText)
    }
}

private struct HorizontalSpan: Hashable {
    var minX: CGFloat
    var maxX: CGFloat

    var width: CGFloat {
        max(maxX - minX, 0)
    }
}

private struct RenderedFragment {
    var rowIndex: Int
    var rowY: CGFloat
    var originX: CGFloat
    var spanWidth: CGFloat
    var attributedText: NSAttributedString
    var ctLine: CTLine
    var ascent: CGFloat
    var descent: CGFloat
    var leading: CGFloat
    var plainText: String
}

private struct RenderPlan {
    var textRect: CGRect
    var rowHeight: CGFloat
    var obstacles: [VisualObstacle]
    var fragments: [RenderedFragment]
    var splitRowIndices: Set<Int>
    var rowCount: Int

    var debugSnapshot: PreparedTextObstacleDebugSnapshot {
        PreparedTextObstacleDebugSnapshot(
            obstacleCount: obstacles.count,
            rowCount: rowCount,
            fragmentCount: fragments.count,
            splitRowCount: splitRowIndices.count,
            renderedStrings: fragments.map(\.plainText)
        )
    }
}

private struct VisualObstacle {
    enum Kind {
        case serpentHead
        case serpentBody
        case serpentTail
        case orb
        case finger
        case trail
    }

    var circle: PreparedTextObstacleCircle
    var alpha: CGFloat
    var fillColor: UIColor
    var strokeColor: UIColor
    var kind: Kind
}

private func normalizedVector(from start: CGPoint, to end: CGPoint) -> CGPoint {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let length = max(hypot(dx, dy), 0.001)
    return CGPoint(x: dx / length, y: dy / length)
}

private func pingPong01(_ value: CGFloat) -> CGFloat {
    let wrapped = value - floor(value)
    if wrapped < 0.5 {
        return wrapped * 2
    }
    return (1 - wrapped) * 2
}
#endif
