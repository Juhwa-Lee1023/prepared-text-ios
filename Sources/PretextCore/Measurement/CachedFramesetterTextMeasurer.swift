import CoreGraphics
import CoreText
import Foundation

public protocol TextMeasurer: AnyObject {
    func measure(_ text: NSAttributedString, width: CGFloat, env: MeasurementEnv) -> CGSize
    func measure(_ text: NSAttributedString, sourceID: PreparedTextSourceID, width: CGFloat, env: MeasurementEnv) -> CGSize
    func invalidateAll()
    var stats: MeasurementStats { get }
}

public final class CachedFramesetterTextMeasurer: TextMeasurer {
    private let lock = NSLock()
    private let cache = CostBoundCache<MeasurementKey, MeasurementCacheEntry>(
        countLimit: 1_024,
        totalCostLimit: 4 * 1_024 * 1_024,
        cost: { entry in
            MemoryLayout<CGSize>.size + ((entry.sourceSnapshot?.length ?? 0) * 4)
        }
    )
    private var inFlightMeasurements: [MeasurementKey: InFlightMeasurement] = [:]
    private var hitCount = 0
    private var missCount = 0

    public init() {}

    public var stats: MeasurementStats {
        lock.withLock {
            MeasurementStats(hitCount: hitCount, missCount: missCount)
        }
    }

    public func measure(_ text: NSAttributedString, width: CGFloat, env: MeasurementEnv) -> CGSize {
        measure(text, identity: .attributed(payloadHash: text.pretextPayloadHash(), runSignatureHash: text.pretextRunSignatureHash()), width: width, env: env)
    }

    public func measure(_ text: NSAttributedString, sourceID: PreparedTextSourceID, width: CGFloat, env: MeasurementEnv) -> CGSize {
        measure(text, identity: .sourceID(sourceID), width: width, env: env)
    }

    public func invalidateAll() {
        lock.withLock {
            hitCount = 0
            missCount = 0
        }
        cache.removeAll()
    }

    func trimForBackground() {
        cache.removeAll()
    }

    private func measure(_ text: NSAttributedString, identity: CacheIdentity, width: CGFloat, env: MeasurementEnv) -> CGSize {
        guard text.length > 0 else {
            return .zero
        }

        let key = MeasurementKey(
            identity: identity,
            widthInPixels: env.normalizedWidth(width),
            env: env
        )

        while true {
            let state: MeasurementLookupState = lock.withLock {
                if let cached = cache.value(forKey: key), cached.matches(text, for: identity) {
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
                if resolved.matches(text, for: identity) {
                    lock.withLock {
                        hitCount += 1
                    }
                    return resolved.size
                }
                continue

            case let .measure(inFlight):
                let snapshot = immutableSnapshot(of: text)
                let measured = measureWithCoreText(snapshot, width: width, env: env)
                let entry = MeasurementCacheEntry(
                    size: measured,
                    sourceSnapshot: identity.requiresSourceValidation ? snapshot : nil
                )

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

    private func immutableSnapshot(of text: NSAttributedString) -> NSAttributedString {
        text.copy() as? NSAttributedString ?? NSAttributedString(attributedString: text)
    }
}

private struct MeasurementCacheEntry {
    let size: CGSize
    let sourceSnapshot: NSAttributedString?

    func matches(_ text: NSAttributedString, for identity: CacheIdentity) -> Bool {
        guard identity.requiresSourceValidation else {
            return true
        }
        guard let sourceSnapshot else {
            return false
        }
        return sourceSnapshot === text || sourceSnapshot.isEqual(to: text)
    }
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
