#if canImport(UIKit) && !os(macOS)
import PretextCore
import UIKit

extension MeasurementCachingLabel {
    @discardableResult
    public func prepared(
        sourceID: PreparedTextSourceID? = nil,
        measurementOptions: PreparedTextMeasurementOptions = .default,
        cacheProfile: PreparedTextCacheProfile? = nil
    ) -> Self {
        self.sourceID = sourceID
        self.measurementOptions = cacheProfile?.measurementOptions ?? measurementOptions
        return self
    }
}
#endif
