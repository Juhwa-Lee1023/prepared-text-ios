import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class PreparedTextSystem: NSObject {
    public static let shared = PreparedTextSystem()

    public let measurer: CachedFramesetterTextMeasurer
    public let engine: DefaultPreparedTextEngine

    public init(measurer: CachedFramesetterTextMeasurer = CachedFramesetterTextMeasurer()) {
        self.measurer = measurer
        self.engine = DefaultPreparedTextEngine(measurer: measurer)
        super.init()
        registerLifecycleObservers()
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
        engine.layout(prepared, maxWidth: maxWidth, lineHeight: lineHeight)
    }

    public func layoutPacket(
        _ prepared: PreparedText,
        maxWidth: CGFloat,
        lineHeight: CGFloat
    ) -> PreparedLayoutPacket {
        engine.layoutPacket(prepared, maxWidth: maxWidth, lineHeight: lineHeight)
    }

    public func attributedText(
        _ prepared: PreparedText,
        from start: LayoutCursor,
        to end: LayoutCursor? = nil,
        flatteningHardBreaks: Bool = false
    ) -> NSAttributedString {
        engine.attributedText(prepared, from: start, to: end, flatteningHardBreaks: flatteningHardBreaks)
    }

    private func registerLifecycleObservers() {
        #if canImport(UIKit)
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleMemoryWarningNotification),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleDidEnterBackgroundNotification),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #endif
    }

    #if canImport(UIKit)
    @objc private func handleMemoryWarningNotification() {
        engine.invalidateCaches()
    }

    @objc private func handleDidEnterBackgroundNotification() {
        engine.trimForBackground()
    }
    #endif
}
