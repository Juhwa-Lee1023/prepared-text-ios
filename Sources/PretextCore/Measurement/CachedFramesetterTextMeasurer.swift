import CoreGraphics
import CoreText
import Foundation

public protocol TextMeasurer: AnyObject {
    func measure(_ text: NSAttributedString, width: CGFloat, env: MeasurementEnv) -> CGSize
    func measure(_ text: NSAttributedString, sourceID: PreparedTextSourceID, width: CGFloat, env: MeasurementEnv) -> CGSize
    func invalidateAll()
    func invalidate(sourceIDs: Set<PreparedTextSourceID>)
    var stats: MeasurementStats { get }
}

public final class CachedFramesetterTextMeasurer: TextMeasurer {
    private let lock = NSLock()
    private let cache: CostBoundCache<MeasurementKey, MeasurementCacheEntry>
    private var inFlightMeasurements: [MeasurementKey: InFlightMeasurement] = [:]
    private var hitCount = 0
    private var missCount = 0

    public convenience init() {
        self.init(countLimit: 1_024, totalCostLimit: 4 * 1_024 * 1_024)
    }

    init(countLimit: Int, totalCostLimit: Int) {
        cache = CostBoundCache(
            countLimit: countLimit,
            totalCostLimit: totalCostLimit,
            cost: { entry in
                max(entry.identity.signature.length, 1) * 4
                    + entry.identity.signature.attributeRunCount * 48
                    + entry.identity.signature.attachmentCount * 384
                    + Int((entry.size.width + entry.size.height).rounded(.up)) * 8
            }
        )
    }

    public var stats: MeasurementStats {
        lock.withLock {
            MeasurementStats(hitCount: hitCount, missCount: missCount, cacheSnapshot: cache.snapshot)
        }
    }

    public func measure(_ text: NSAttributedString, width: CGFloat, env: MeasurementEnv) -> CGSize {
        let signature = text.pretextLayoutSignature()
        return measure(text, identity: .attributed(signature), width: width, env: env)
    }

    public func measure(_ text: NSAttributedString, sourceID: PreparedTextSourceID, width: CGFloat, env: MeasurementEnv) -> CGSize {
        let signature = text.pretextLayoutSignature()
        return measure(text, identity: .sourceID(sourceID, signature), width: width, env: env)
    }

    public func invalidateAll() {
        lock.withLock {
            hitCount = 0
            missCount = 0
            inFlightMeasurements.removeAll(keepingCapacity: false)
        }
        cache.removeAll()
    }

    public func invalidate(sourceIDs: Set<PreparedTextSourceID>) {
        guard !sourceIDs.isEmpty else {
            return
        }

        lock.withLock {
            inFlightMeasurements = inFlightMeasurements.filter { key, _ in
                guard let sourceID = key.identity.sourceID else {
                    return true
                }
                return !sourceIDs.contains(sourceID)
            }
        }

        cache.removeAll { key, _ in
            guard let sourceID = key.identity.sourceID else {
                return false
            }
            return sourceIDs.contains(sourceID)
        }
    }

    func trimForBackground() {
        let snapshot = cache.snapshot
        let targetCount = snapshot.countLimit.map { max($0 / 2, 1) }
        let targetCost = snapshot.totalCostLimit.map { max($0 / 2, 1) }
        cache.trim(countLimit: targetCount, totalCostLimit: targetCost)
    }

    private func measure(_ text: NSAttributedString, identity: CacheIdentity, width: CGFloat, env: MeasurementEnv) -> CGSize {
        guard text.length > 0 else {
            return .zero
        }

        let resolvedWidth = env.resolvedMeasurementWidth(width)
        let key = MeasurementKey(
            identity: identity,
            widthInPixels: env.normalizedWidth(width),
            env: env
        )

        while true {
            let state: MeasurementLookupState = lock.withLock {
                if let cached = cache.value(forKey: key), cached.identity == identity {
                    hitCount += 1
                    return .hit(cached)
                }

                if let existing = inFlightMeasurements[key] {
                    return .wait(existing)
                }

                missCount += 1
                let token = InFlightMeasurement()
                inFlightMeasurements[key] = token
                return .measure(token)
            }

            switch state {
            case let .hit(cached):
                return cached.size

            case let .wait(inFlight):
                let resolved = inFlight.waitForResult()
                if resolved.identity == identity {
                    lock.withLock {
                        hitCount += 1
                    }
                    return resolved.size
                }
                continue

            case let .measure(inFlight):
                let measured = PreparedTextSignposts.measure("Stage0Measure") {
                    measureWithCoreText(text, width: resolvedWidth, env: env)
                }
                let entry = MeasurementCacheEntry(size: measured, identity: identity)

                lock.withLock {
                    cache.insert(entry, forKey: key)
                    inFlightMeasurements.removeValue(forKey: key)
                }
                inFlight.complete(with: entry)
                return measured
            }
        }
    }

    private func measureWithCoreText(_ text: NSAttributedString, width: CGFloat, env: MeasurementEnv) -> CGSize {
        let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
        let constraintWidth = width.isFinite ? max(width, 0) : .greatestFiniteMagnitude
        let measured = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: constraintWidth, height: .greatestFiniteMagnitude),
            nil
        )

        let normalizedScale = CGFloat(max(env.scale, 1))
        let normalizedWidth = (measured.width * normalizedScale).rounded(.up) / normalizedScale
        let normalizedHeight = (measured.height * normalizedScale).rounded(.up) / normalizedScale

        return CGSize(width: normalizedWidth, height: normalizedHeight)
    }
}

private struct MeasurementCacheEntry {
    let size: CGSize
    let identity: CacheIdentity
}

private final class InFlightMeasurement {
    private let condition = NSCondition()
    private var result: MeasurementCacheEntry?

    func waitForResult() -> MeasurementCacheEntry {
        condition.lock()
        defer { condition.unlock() }

        while result == nil {
            condition.wait()
        }
        return result!
    }

    func complete(with result: MeasurementCacheEntry) {
        condition.lock()
        self.result = result
        condition.broadcast()
        condition.unlock()
    }
}

private enum MeasurementLookupState {
    case hit(MeasurementCacheEntry)
    case wait(InFlightMeasurement)
    case measure(InFlightMeasurement)
}
