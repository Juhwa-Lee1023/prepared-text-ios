#if canImport(UIKit) && !os(macOS)
import PretextCore
import UIKit

extension MeasurementCachingLabel {
    @discardableResult
    public func prepared(
        sourceID: PreparedTextSourceID? = nil,
        measurementOptions: PreparedTextMeasurementOptions = .default
    ) -> Self {
        self.sourceID = sourceID
        self.measurementOptions = measurementOptions
        return self
    }
}
#endif
