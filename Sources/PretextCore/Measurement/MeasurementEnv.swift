import CoreGraphics
import Foundation

/// Controls how proposed widths participate in cache identity and, when enabled,
/// how aggressively nearby widths are intentionally coalesced.
public enum WidthNormalizationPolicy: Hashable, Sendable {
    /// Treat each proposed width as distinct at pixel granularity.
    case exactPixels

    /// Reuse a narrower bucket for nearby widths.
    ///
    /// The bucket is applied conservatively by flooring to the nearest bucket
    /// below the proposed width once the width is larger than the bucket size.
    /// This can over-measure height slightly, but avoids under-measuring height
    /// for self-sizing surfaces.
    case bucketed(points: CGFloat)

    func normalizedWidth(_ width: CGFloat, scale: CGFloat) -> CGFloat {
        let clamped = max(width, 0)
        switch self {
        case .exactPixels:
            return clamped

        case let .bucketed(points):
            let bucket = max(points, 0)
            guard bucket > 0, clamped >= bucket else {
                return clamped
            }

            let floored = floor(clamped / bucket) * bucket
            let minimumStep = 1 / max(scale, 1)
            return max(floored, minimumStep)
        }
    }
}

/// Controls whether proposed widths are first aligned to the device pixel grid.
public enum PixelMeasurementPolicy: String, Hashable, Sendable {
    /// Preserve fractional proposals exactly.
    case exact

    /// Align proposals to the current display scale before measuring and caching.
    case alignedToScale
}

/// Narrow cache/reuse presets for repeated-width read-only surfaces.
///
/// These presets remain conservative wrappers around `PreparedTextMeasurementOptions`.
/// They do not change layout semantics; they only tune width coalescing and pixel alignment.
public enum PreparedTextCacheProfile: String, Hashable, Sendable {
    /// Recommended default for mixed list/card adoption. Coalesces nearby widths conservatively.
    case balanced

    /// Favors stronger nearby-width reuse for fast-scrolling feeds and repeated self-sizing.
    case aggressive

    /// Keeps prepared measurement packets sticky across broader width negotiations.
    case stickyPrepared

    public var measurementOptions: PreparedTextMeasurementOptions {
        switch self {
        case .balanced:
            return PreparedTextMeasurementOptions(
                widthNormalizationPolicy: .bucketed(points: 4),
                pixelMeasurementPolicy: .alignedToScale
            )
        case .aggressive:
            return PreparedTextMeasurementOptions(
                widthNormalizationPolicy: .bucketed(points: 8),
                pixelMeasurementPolicy: .alignedToScale
            )
        case .stickyPrepared:
            return PreparedTextMeasurementOptions(
                widthNormalizationPolicy: .bucketed(points: 12),
                pixelMeasurementPolicy: .alignedToScale
            )
        }
    }
}

/// Public measurement knobs for prepared-text sizing and layout reuse.
public struct PreparedTextMeasurementOptions: Hashable, Sendable {
    public var widthNormalizationPolicy: WidthNormalizationPolicy
    public var pixelMeasurementPolicy: PixelMeasurementPolicy

    public init(
        widthNormalizationPolicy: WidthNormalizationPolicy = .exactPixels,
        pixelMeasurementPolicy: PixelMeasurementPolicy = .exact
    ) {
        self.widthNormalizationPolicy = widthNormalizationPolicy
        self.pixelMeasurementPolicy = pixelMeasurementPolicy
    }

    public init(cacheProfile: PreparedTextCacheProfile) {
        self = cacheProfile.measurementOptions
    }

    public static let `default` = PreparedTextMeasurementOptions()
}

public struct MeasurementEnv: Sendable {
    public var scale: Double
    public var contentSizeCategory: String
    public var localeIdentifier: String?
    public var measurementOptions: PreparedTextMeasurementOptions

    public init(
        scale: Double = 1,
        contentSizeCategory: String = "unspecified",
        localeIdentifier: String? = nil,
        measurementOptions: PreparedTextMeasurementOptions = .default
    ) {
        self.scale = scale
        self.contentSizeCategory = contentSizeCategory
        self.localeIdentifier = localeIdentifier
        self.measurementOptions = measurementOptions
    }

    public static let `default` = MeasurementEnv()

    public var resolvedScale: CGFloat {
        CGFloat(max(scale, 1))
    }

    public func normalizedWidth(_ width: CGFloat) -> Int {
        let resolved = resolvedMeasurementWidth(width)
        guard resolved.isFinite else {
            return Int.max
        }

        let product = (Double(resolved) * Double(resolvedScale)).rounded(.up)
        guard product.isFinite else {
            return Int.max
        }

        let clamped = min(max(product, 0), Double(Int.max))
        return Int(clamped)
    }

    public func resolvedMeasurementWidth(_ width: CGFloat) -> CGFloat {
        guard width.isFinite else {
            return .greatestFiniteMagnitude
        }

        let aligned = pixelAlignedValue(width)
        return measurementOptions.widthNormalizationPolicy.normalizedWidth(aligned, scale: resolvedScale)
    }

    public func cacheScalarKey(_ value: CGFloat) -> Int {
        guard value.isFinite else {
            return Int.max
        }

        let clamped = max(value, 0)
        let scaled = (Double(clamped) * 1_000).rounded(.up)
        return Int(min(max(scaled, 0), Double(Int.max)))
    }

    private func pixelAlignedValue(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else {
            return value
        }

        switch measurementOptions.pixelMeasurementPolicy {
        case .exact:
            return max(value, 0)
        case .alignedToScale:
            let scale = max(resolvedScale, 1)
            return (max(value, 0) * scale).rounded(.toNearestOrAwayFromZero) / scale
        }
    }
}

public struct MeasurementStats: Hashable, Sendable {
    public var hitCount: Int
    public var missCount: Int
    public var evictionCount: Int
    public var currentEntryCount: Int
    public var currentCost: Int
    public var countLimit: Int?
    public var totalCostLimit: Int?

    public init(
        hitCount: Int = 0,
        missCount: Int = 0,
        evictionCount: Int = 0,
        currentEntryCount: Int = 0,
        currentCost: Int = 0,
        countLimit: Int? = nil,
        totalCostLimit: Int? = nil
    ) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.evictionCount = evictionCount
        self.currentEntryCount = currentEntryCount
        self.currentCost = currentCost
        self.countLimit = countLimit
        self.totalCostLimit = totalCostLimit
    }

    public var totalCount: Int {
        hitCount + missCount
    }

    public var hitRate: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(hitCount) / Double(totalCount)
    }

    public var missRate: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(missCount) / Double(totalCount)
    }

    init(hitCount: Int, missCount: Int, cacheSnapshot: CacheDiagnosticsSnapshot) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.evictionCount = cacheSnapshot.evictionCount
        self.currentEntryCount = cacheSnapshot.currentEntryCount
        self.currentCost = cacheSnapshot.currentCost
        self.countLimit = cacheSnapshot.countLimit
        self.totalCostLimit = cacheSnapshot.totalCostLimit
    }
}

extension NSLock {
    @discardableResult
    func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}
