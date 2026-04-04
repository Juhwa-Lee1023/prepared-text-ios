#if canImport(UIKit) && !os(macOS)
import PretextCore
import UIKit

public enum PreparedTextSurfaceMode: String, Hashable, Sendable {
    case stage0MeasureOnly
    case stage1Prepared
}

@MainActor
public final class MeasurementCachingLabelAdapter {
    public var textSystem: PreparedTextSystem

    public init(textSystem: PreparedTextSystem = .shared) {
        self.textSystem = textSystem
    }

    public func measure(
        _ attributedText: NSAttributedString,
        width: CGFloat,
        traitCollection: UITraitCollection,
        displayScale: CGFloat? = nil,
        sourceID: PreparedTextSourceID? = nil
    ) -> CGSize {
        let resolvedDisplayScale = displayScale ?? traitCollection.displayScale
        let env = MeasurementEnv(
            scale: Double(resolvedDisplayScale > 0 ? resolvedDisplayScale : UIScreen.main.scale),
            contentSizeCategory: traitCollection.preferredContentSizeCategory.rawValue
        )

        if let sourceID {
            return textSystem.measurer.measure(attributedText, sourceID: sourceID, width: width, env: env)
        }
        return textSystem.measure(attributedText, width: width, env: env)
    }
}

@MainActor
public final class MeasurementCachingLabel: UILabel {
    public let measurementAdapter: MeasurementCachingLabelAdapter
    public var sourceID: PreparedTextSourceID?

    public override init(frame: CGRect) {
        self.measurementAdapter = MeasurementCachingLabelAdapter()
        super.init(frame: frame)
        numberOfLines = 0
    }

    public required init?(coder: NSCoder) {
        self.measurementAdapter = MeasurementCachingLabelAdapter()
        super.init(coder: coder)
        numberOfLines = 0
    }

    public override var intrinsicContentSize: CGSize {
        guard let attributedText else {
            return .zero
        }
        return measurementAdapter.measure(
            attributedText,
            width: preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : 10_000,
            traitCollection: traitCollection,
            displayScale: window?.screen.scale,
            sourceID: sourceID
        )
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let attributedText else {
            return .zero
        }
        let width = size.width > 0 ? size.width : (preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : 10_000)
        return measurementAdapter.measure(
            attributedText,
            width: width,
            traitCollection: traitCollection,
            displayScale: window?.screen.scale,
            sourceID: sourceID
        )
    }

    public override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority _: UILayoutPriority
    ) -> CGSize {
        guard let attributedText else {
            return .zero
        }
        let width: CGFloat
        if horizontalFittingPriority == .required, targetSize.width > 0 {
            width = targetSize.width
        } else if preferredMaxLayoutWidth > 0 {
            width = preferredMaxLayoutWidth
        } else if bounds.width > 0 {
            width = bounds.width
        } else {
            width = 10_000
        }
        return measurementAdapter.measure(
            attributedText,
            width: width,
            traitCollection: traitCollection,
            displayScale: window?.screen.scale,
            sourceID: sourceID
        )
    }
}
#endif
