import CoreGraphics
import Foundation

#if canImport(CoreText)
import CoreText
#endif

#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class PreparedTextSystem: NSObject {
    private struct ObserverToken: @unchecked Sendable {
        let rawValue: NSObjectProtocol
        let notificationCenter: NotificationCenter
    }

    public static let shared = PreparedTextSystem()

    public let measurer: CachedFramesetterTextMeasurer
    public let engine: DefaultPreparedTextEngine
    public let attachmentResolver: PreparedAttachmentResolving?

    private let invalidationCenter: PreparedInvalidationCenter
    private var observerTokens: [ObserverToken] = []

    public init(
        measurer: CachedFramesetterTextMeasurer = CachedFramesetterTextMeasurer(),
        invalidationCenter: PreparedInvalidationCenter = .shared,
        attachmentResolver: PreparedAttachmentResolving? = PreparedAttachmentRegistry.shared
    ) {
        self.measurer = measurer
        self.attachmentResolver = attachmentResolver
        self.engine = DefaultPreparedTextEngine(
            measurer: measurer,
            attachmentResolver: attachmentResolver
        )
        self.invalidationCenter = invalidationCenter
        super.init()
        registerLifecycleObservers()
        registerInvalidationObservers()
    }

    deinit {
        observerTokens.forEach { $0.notificationCenter.removeObserver($0.rawValue) }
    }

    public func measure(
        _ attributedText: NSAttributedString,
        width: CGFloat,
        env: MeasurementEnv = .default
    ) -> CGSize {
        measurer.measure(attributedText, width: width, env: env)
    }

    public func prepare(
        _ attributedText: NSAttributedString,
        options: PreparedTextOptions = PreparedTextOptions()
    ) -> PreparedText {
        engine.prepare(attributedText, options: options)
    }

    public func prepare(
        _ attributedText: NSAttributedString,
        sourceID: PreparedTextSourceID,
        options: PreparedTextOptions = PreparedTextOptions()
    ) -> PreparedText {
        engine.prepare(attributedText, sourceID: sourceID, options: options)
    }

    public func layout(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat
    ) -> LayoutResult {
        engine.layout(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: .default)
    }

    public func layout(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        env: MeasurementEnv
    ) -> LayoutResult {
        engine.layout(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: env)
    }

    public func layout(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        env: MeasurementEnv = .default,
        options: PreparedTextLayoutOptions
    ) -> LayoutResult {
        engine.layout(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: env, options: options)
    }

    public func layoutPacket(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat
    ) -> PreparedLayoutPacket {
        engine.layoutPacket(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: .default)
    }

    public func layoutPacket(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        env: MeasurementEnv
    ) -> PreparedLayoutPacket {
        engine.layoutPacket(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: env)
    }

    public func layoutPacket(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        env: MeasurementEnv = .default,
        options: PreparedTextLayoutOptions
    ) -> PreparedLayoutPacket {
        engine.layoutPacket(prepared, maxWidth: maxWidth, lineHeight: lineHeight, env: env, options: options)
    }

    public func displayLayoutPacket(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        containerWidth: CGFloat? = nil,
        env: MeasurementEnv = .default,
        options: PreparedTextLayoutOptions = .default
    ) -> PreparedTextDisplayPacket {
        engine.displayLayoutPacket(
            prepared,
            maxWidth: maxWidth,
            lineHeight: lineHeight,
            containerWidth: containerWidth,
            env: env,
            options: options
        )
    }

    public func sourceCoordinateMap(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat,
        containerWidth: CGFloat? = nil,
        env: MeasurementEnv = .default,
        options: PreparedTextLayoutOptions = .default
    ) -> PreparedTextSourceCoordinateMap {
        engine.sourceCoordinateMap(
            prepared,
            maxWidth: maxWidth,
            lineHeight: lineHeight,
            containerWidth: containerWidth,
            env: env,
            options: options
        )
    }

    public func tokens(in prepared: PreparedText) -> [PreparedToken] {
        prepared.tokens
    }

    public func annotations(in prepared: PreparedText) -> [PreparedAnnotation] {
        prepared.annotations
    }

    public func attachmentSpans(in prepared: PreparedText) -> [PreparedAttachmentSpan] {
        prepared.attachmentSpans
    }

    public func attributedText(
        _ prepared: PreparedText,
        from start: LayoutCursor,
        to end: LayoutCursor? = nil,
        flatteningHardBreaks: Bool = false
    ) -> NSAttributedString {
        engine.attributedText(prepared, from: start, to: end, flatteningHardBreaks: flatteningHardBreaks)
    }

    public func invalidateAll(reason: PreparedInvalidationReason = .manual) {
        engine.invalidateCaches(reason: reason)
    }

    public func invalidate(sourceIDs: Set<PreparedTextSourceID>, reason: PreparedInvalidationReason = .manual) {
        engine.invalidateCaches(sourceIDs: sourceIDs, reason: reason)
    }

    public func trimForBackground(reason: PreparedInvalidationReason = .backgroundTrim) {
        engine.trimForBackground(reason: reason)
    }

    public func diagnosticsSnapshot() -> PreparedTextDiagnosticsSnapshot {
        engine.diagnosticsSnapshot()
    }

    private func registerInvalidationObservers() {
        let center = invalidationCenter.observerNotificationCenter
        let token = center.addObserver(
            forName: PreparedInvalidationCenter.notificationName,
            object: invalidationCenter,
            queue: nil
        ) { [weak self] notification in
            guard
                let self,
                let request = notification.userInfo?[PreparedInvalidationCenter.requestUserInfoKey] as? PreparedInvalidationRequest
            else {
                return
            }

            Task { @MainActor in
                self.applyInvalidation(request)
            }
        }
        observerTokens.append(ObserverToken(rawValue: token, notificationCenter: center))
    }

    private func registerLifecycleObservers() {
        #if canImport(UIKit)
        let center = NotificationCenter.default

        observerTokens.append(
            ObserverToken(rawValue: center.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.applyInvalidation(.init(scope: .all, reason: .memoryWarning))
                }
            }, notificationCenter: center)
        )

        observerTokens.append(
            ObserverToken(rawValue: center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.applyInvalidation(.init(scope: .backgroundTrim, reason: .backgroundTrim))
                }
            }, notificationCenter: center)
        )

        observerTokens.append(
            ObserverToken(rawValue: center.addObserver(
                forName: UIContentSizeCategory.didChangeNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.applyInvalidation(.init(scope: .all, reason: .contentSizeCategoryChanged))
                }
            }, notificationCenter: center)
        )
        #endif

        let localeCenter = NotificationCenter.default
        observerTokens.append(
            ObserverToken(rawValue: localeCenter.addObserver(
                forName: NSLocale.currentLocaleDidChangeNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.applyInvalidation(.init(scope: .all, reason: .localeChanged))
                }
            }, notificationCenter: localeCenter)
        )

        #if canImport(CoreText)
        observerTokens.append(
            ObserverToken(rawValue: localeCenter.addObserver(
                forName: Notification.Name(kCTFontManagerRegisteredFontsChangedNotification as String),
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.applyInvalidation(.init(scope: .all, reason: .fontSetChanged))
                }
            }, notificationCenter: localeCenter)
        )
        #endif
    }

    private func applyInvalidation(_ request: PreparedInvalidationRequest) {
        switch request.scope {
        case .all:
            engine.invalidateCaches(reason: request.reason)
        case let .sourceIDs(sourceIDs):
            engine.invalidateCaches(sourceIDs: sourceIDs, reason: request.reason)
        case .backgroundTrim:
            engine.trimForBackground(reason: request.reason)
        }
    }
}
