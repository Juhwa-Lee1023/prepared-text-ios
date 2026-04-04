#if canImport(UIKit) && !os(macOS)
import ObjectiveC.runtime
import PretextCore
import UIKit

public enum PreparedUILabelParticipation: Hashable, Sendable {
    case inheritGlobal
    case enabled(sourceID: PreparedTextSourceID? = nil)
    case disabled
}

public struct LegacyUILabelSupportConfiguration: Hashable, Sendable {
    public enum Scope: Hashable, Sendable {
        case optInOnly
        case multilineOnly
        case allLabels
    }

    public var scope: Scope
    public var excludeInteractiveLabels: Bool
    public var excludeAttributedLinks: Bool
    public var swizzleSystemLayoutSizeFitting: Bool

    public init(
        scope: Scope,
        excludeInteractiveLabels: Bool = true,
        excludeAttributedLinks: Bool = true,
        swizzleSystemLayoutSizeFitting: Bool = true
    ) {
        self.scope = scope
        self.excludeInteractiveLabels = excludeInteractiveLabels
        self.excludeAttributedLinks = excludeAttributedLinks
        self.swizzleSystemLayoutSizeFitting = swizzleSystemLayoutSizeFitting
    }

    public static let optInOnly = LegacyUILabelSupportConfiguration(scope: .optInOnly)
    public static let legacyMultiline = LegacyUILabelSupportConfiguration(
        scope: .multilineOnly,
        excludeInteractiveLabels: true,
        excludeAttributedLinks: true,
        swizzleSystemLayoutSizeFitting: true
    )
}

/// Explicit Stage 0 adoption support for legacy `UILabel` sizing paths.
///
/// This support is intentionally limited to measurement caching. It does not replace
/// `UILabel` drawing with the Stage 1 prepared renderer. Stage 1 remains explicit through
/// `PreparedLabelView` / `PreparedTextView`.
public enum PreparedTextLegacySupport {
    @MainActor
    public static func installUILabelSupport(
        _ configuration: LegacyUILabelSupportConfiguration = .optInOnly
    ) {
        swizzleUILabelMethodsIfNeeded()
        PreparedTextLegacyUILabelState.lock.withLock {
            PreparedTextLegacyUILabelState.configuration = configuration
        }
    }

    @MainActor
    public static func currentUILabelSupportConfiguration() -> LegacyUILabelSupportConfiguration? {
        PreparedTextLegacyUILabelState.lock.withLock {
            PreparedTextLegacyUILabelState.configuration
        }
    }

    @MainActor
    static func invalidate(_ label: UILabel) {
        label.invalidateIntrinsicContentSize()
        label.setNeedsLayout()
    }

    @MainActor
    static func preparedMeasurementSize(for label: UILabel, sizing: PreparedLegacyLabelSizing) -> CGSize? {
        guard let measurementRequest = measurementRequest(for: label, sizing: sizing) else {
            return nil
        }
        return sharedMeasurementAdapter().measure(
            measurementRequest.attributedText,
            width: measurementRequest.width,
            traitCollection: label.traitCollection,
            displayScale: label.window?.screen.scale,
            sourceID: measurementRequest.sourceID
        )
    }

    @MainActor
    internal static func _resetUILabelSupportForTesting() {
        PreparedTextLegacyUILabelState.lock.withLock {
            PreparedTextLegacyUILabelState.configuration = nil
            PreparedTextLegacyUILabelState.measurementAdapter = nil
        }
    }

    @MainActor
    private static func sharedMeasurementAdapter() -> MeasurementCachingLabelAdapter {
        if let adapter = PreparedTextLegacyUILabelState.lock.withLock({
            PreparedTextLegacyUILabelState.measurementAdapter
        }) {
            return adapter
        }

        let adapter = MeasurementCachingLabelAdapter()
        PreparedTextLegacyUILabelState.lock.withLock {
            PreparedTextLegacyUILabelState.measurementAdapter = adapter
        }
        return adapter
    }

    @MainActor
    private static func measurementRequest(
        for label: UILabel,
        sizing: PreparedLegacyLabelSizing
    ) -> PreparedLegacyMeasurementRequest? {
        let participation = label.preparedParticipation
        guard let configuration = currentUILabelSupportConfiguration() else {
            return nil
        }

        let sourceID: PreparedTextSourceID?
        switch participation {
        case .disabled:
            return nil
        case let .enabled(explicitSourceID):
            sourceID = explicitSourceID
        case .inheritGlobal:
            guard isEligibleForGlobalSupport(label, configuration: configuration) else {
                return nil
            }
            sourceID = nil
        }

        if case .systemLayoutSizeFitting = sizing, !configuration.swizzleSystemLayoutSizeFitting {
            return nil
        }

        guard let attributedText = label.pretextMeasurementAttributedText(), attributedText.length > 0 else {
            return nil
        }

        return PreparedLegacyMeasurementRequest(
            attributedText: attributedText,
            width: sizing.resolvedWidth(for: label),
            sourceID: sourceID
        )
    }

    @MainActor
    private static func isEligibleForGlobalSupport(
        _ label: UILabel,
        configuration: LegacyUILabelSupportConfiguration
    ) -> Bool {
        switch configuration.scope {
        case .optInOnly:
            return false
        case .multilineOnly:
            // The Stage 0 UILabel rollout only measures full multiline copy.
            // Finite line limits keep truncation semantics in the system stack.
            guard label.numberOfLines == 0 else {
                return false
            }
        case .allLabels:
            break
        }

        if configuration.excludeInteractiveLabels, label.pretextIsInteractive {
            return false
        }

        if configuration.excludeAttributedLinks, label.pretextContainsAttributedLinks {
            return false
        }

        return true
    }

    private static func swizzleUILabelMethodsIfNeeded() {
        let selectors: [(Selector, Selector)] = [
            (#selector(getter: UIView.intrinsicContentSize), #selector(UILabel.pretext_preparedIntrinsicContentSize)),
            (#selector(UIView.sizeThatFits(_:)), #selector(UILabel.pretext_preparedSizeThatFits(_:))),
            (
                #selector(UIView.systemLayoutSizeFitting(_:withHorizontalFittingPriority:verticalFittingPriority:)),
                #selector(UILabel.pretext_preparedSystemLayoutSizeFitting(_:withHorizontalFittingPriority:verticalFittingPriority:))
            ),
        ]

        PreparedTextLegacyUILabelState.lock.withLock {
            guard !PreparedTextLegacyUILabelState.didSwizzleMethods else {
                return
            }

            selectors.forEach { original, swizzled in
                guard
                    let originalMethod = class_getInstanceMethod(UILabel.self, original),
                    let swizzledMethod = class_getInstanceMethod(UILabel.self, swizzled)
                else {
                    return
                }
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
            PreparedTextLegacyUILabelState.didSwizzleMethods = true
        }
    }
}

private enum PreparedTextLegacyUILabelState {
    static let lock = NSLock()
    nonisolated(unsafe) static var configuration: LegacyUILabelSupportConfiguration?
    nonisolated(unsafe) static var didSwizzleMethods = false
    nonisolated(unsafe) static var measurementAdapter: MeasurementCachingLabelAdapter?
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

private struct PreparedLegacyMeasurementRequest {
    var attributedText: NSAttributedString
    var width: CGFloat
    var sourceID: PreparedTextSourceID?
}

enum PreparedLegacyLabelSizing {
    case intrinsic
    case sizeThatFits(CGSize)
    case systemLayoutSizeFitting(CGSize, UILayoutPriority)

    @MainActor
    func resolvedWidth(for label: UILabel) -> CGFloat {
        switch self {
        case .intrinsic:
            if label.preferredMaxLayoutWidth > 0 {
                return label.preferredMaxLayoutWidth
            }
            return 10_000

        case let .sizeThatFits(size):
            if size.width.isFinite, size.width > 0 {
                return size.width
            }
            if label.preferredMaxLayoutWidth > 0 {
                return label.preferredMaxLayoutWidth
            }
            if label.bounds.width > 0 {
                return label.bounds.width
            }
            return 10_000

        case let .systemLayoutSizeFitting(targetSize, horizontalPriority):
            if horizontalPriority == .required, targetSize.width.isFinite, targetSize.width > 0 {
                return targetSize.width
            }
            if label.preferredMaxLayoutWidth > 0 {
                return label.preferredMaxLayoutWidth
            }
            if label.bounds.width > 0 {
                return label.bounds.width
            }
            return 10_000
        }
    }
}

private enum PreparedUILabelAssociationKeys {
    nonisolated(unsafe) static var participation: UInt8 = 0
}

private final class PreparedUILabelParticipationBox: NSObject {
    let participation: PreparedUILabelParticipation

    init(_ participation: PreparedUILabelParticipation) {
        self.participation = participation
    }
}

extension UILabel {
    @MainActor
    var preparedParticipationStorage: PreparedUILabelParticipation {
        get {
            if let box = objc_getAssociatedObject(self, &PreparedUILabelAssociationKeys.participation) as? PreparedUILabelParticipationBox {
                return box.participation
            }
            return .inheritGlobal
        }
        set {
            objc_setAssociatedObject(
                self,
                &PreparedUILabelAssociationKeys.participation,
                PreparedUILabelParticipationBox(newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    @MainActor
    fileprivate var pretextIsInteractive: Bool {
        isUserInteractionEnabled || !(gestureRecognizers?.isEmpty ?? true)
    }

    @MainActor
    fileprivate var pretextContainsAttributedLinks: Bool {
        guard let attributedText, attributedText.length > 0 else {
            return false
        }

        var containsLink = false
        attributedText.enumerateAttribute(.link, in: NSRange(location: 0, length: attributedText.length), options: []) { value, _, stop in
            if value != nil {
                containsLink = true
                stop.pointee = true
            }
        }
        return containsLink
    }

    @MainActor
    fileprivate func pretextMeasurementAttributedText() -> NSAttributedString? {
        if let attributedText, attributedText.length > 0 {
            return attributedText
        }

        guard let text, !text.isEmpty else {
            return nil
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineBreakMode = lineBreakMode
        if #available(iOS 14.0, *) {
            paragraphStyle.lineBreakStrategy = lineBreakStrategy
        }

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font as Any,
                .paragraphStyle: paragraphStyle,
            ]
        )
    }

    @objc fileprivate func pretext_preparedIntrinsicContentSize() -> CGSize {
        if let measured = PreparedTextLegacySupport.preparedMeasurementSize(for: self, sizing: .intrinsic) {
            return measured
        }
        return pretext_preparedIntrinsicContentSize()
    }

    @objc fileprivate func pretext_preparedSizeThatFits(_ size: CGSize) -> CGSize {
        if let measured = PreparedTextLegacySupport.preparedMeasurementSize(for: self, sizing: .sizeThatFits(size)) {
            return measured
        }
        return pretext_preparedSizeThatFits(size)
    }

    @objc fileprivate func pretext_preparedSystemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        if let measured = PreparedTextLegacySupport.preparedMeasurementSize(
            for: self,
            sizing: .systemLayoutSizeFitting(targetSize, horizontalFittingPriority)
        ) {
            return measured
        }
        return pretext_preparedSystemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
    }
}
#endif
