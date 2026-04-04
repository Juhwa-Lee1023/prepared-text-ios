import Foundation

public struct PreparedTextInvalidationStats: Hashable, Sendable {
    public var fullInvalidationCount: Int
    public var targetedInvalidationCount: Int
    public var backgroundTrimCount: Int
    public var lastReason: PreparedInvalidationReason?

    public init(
        fullInvalidationCount: Int = 0,
        targetedInvalidationCount: Int = 0,
        backgroundTrimCount: Int = 0,
        lastReason: PreparedInvalidationReason? = nil
    ) {
        self.fullInvalidationCount = fullInvalidationCount
        self.targetedInvalidationCount = targetedInvalidationCount
        self.backgroundTrimCount = backgroundTrimCount
        self.lastReason = lastReason
    }
}

public struct PreparedTextDiagnosticsSnapshot: Hashable, Sendable {
    public var measurementCache: MeasurementStats
    public var preparedTextCache: CacheDiagnosticsSnapshot
    public var layoutPacketCache: CacheDiagnosticsSnapshot
    public var segmentMeasurementCache: CacheDiagnosticsSnapshot
    public var layoutPacketReuseCount: Int
    public var averageLinesPerLayout: Double
    public var invalidations: PreparedTextInvalidationStats

    public init(
        measurementCache: MeasurementStats,
        preparedTextCache: CacheDiagnosticsSnapshot,
        layoutPacketCache: CacheDiagnosticsSnapshot,
        segmentMeasurementCache: CacheDiagnosticsSnapshot,
        layoutPacketReuseCount: Int = 0,
        averageLinesPerLayout: Double = 0,
        invalidations: PreparedTextInvalidationStats = PreparedTextInvalidationStats()
    ) {
        self.measurementCache = measurementCache
        self.preparedTextCache = preparedTextCache
        self.layoutPacketCache = layoutPacketCache
        self.segmentMeasurementCache = segmentMeasurementCache
        self.layoutPacketReuseCount = layoutPacketReuseCount
        self.averageLinesPerLayout = averageLinesPerLayout
        self.invalidations = invalidations
    }
}
