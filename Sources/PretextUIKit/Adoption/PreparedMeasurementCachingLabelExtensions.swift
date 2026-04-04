#if canImport(UIKit) && !os(macOS)
import PretextCore
import UIKit

extension MeasurementCachingLabel {
    @discardableResult
    public func prepared(sourceID: PreparedTextSourceID? = nil) -> Self {
        self.sourceID = sourceID
        return self
    }
}
#endif
