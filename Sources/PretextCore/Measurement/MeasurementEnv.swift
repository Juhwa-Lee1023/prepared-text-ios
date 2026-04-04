import CoreGraphics
import Foundation

public struct MeasurementEnv: Hashable, Sendable {
    public var scale: Double
    public var contentSizeCategory: String

    public init(
        scale: Double = 1,
        contentSizeCategory: String = "unspecified"
    ) {
        self.scale = scale
        self.contentSizeCategory = contentSizeCategory
    }

    public static let `default` = MeasurementEnv()

    public func normalizedWidth(_ width: CGFloat) -> Int {
        guard width.isFinite else {
            return Int.max
        }

        let normalizedScale = max(scale, 1)
        let product = (Double(width) * normalizedScale).rounded(.up)

        guard product.isFinite else {
            return Int.max
        }

        let clamped = min(max(product, 0), Double(Int.max))
        return Int(clamped)
    }
}

public struct MeasurementStats: Hashable, Sendable {
    public var hitCount: Int
    public var missCount: Int

    public init(hitCount: Int = 0, missCount: Int = 0) {
        self.hitCount = hitCount
        self.missCount = missCount
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
}

extension NSLock {
    @discardableResult
    func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}
