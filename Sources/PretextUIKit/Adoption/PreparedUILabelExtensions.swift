#if canImport(UIKit) && !os(macOS)
import PretextCore
import UIKit

extension UILabel {
    public var preparedParticipation: PreparedUILabelParticipation {
        get {
            preparedParticipationStorage
        }
        set {
            preparedParticipationStorage = newValue
            PreparedTextLegacySupport.invalidate(self)
        }
    }

    @discardableResult
    public func prepared(
        sourceID: PreparedTextSourceID? = nil,
        installIfNeeded: Bool = true
    ) -> Self {
        if installIfNeeded, PreparedTextLegacySupport.currentUILabelSupportConfiguration() == nil {
            PreparedTextLegacySupport.installUILabelSupport(.optInOnly)
        }
        preparedParticipation = .enabled(sourceID: sourceID)
        return self
    }

    @discardableResult
    public func unprepared() -> Self {
        preparedParticipation = .disabled
        return self
    }
}
#endif
