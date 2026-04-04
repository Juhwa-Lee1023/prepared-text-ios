import Foundation

public struct CacheDiagnosticsSnapshot: Hashable, Sendable {
    public var hitCount: Int
    public var missCount: Int
    public var insertCount: Int
    public var evictionCount: Int
    public var currentEntryCount: Int
    public var currentCost: Int
    public var countLimit: Int?
    public var totalCostLimit: Int?

    public init(
        hitCount: Int = 0,
        missCount: Int = 0,
        insertCount: Int = 0,
        evictionCount: Int = 0,
        currentEntryCount: Int = 0,
        currentCost: Int = 0,
        countLimit: Int? = nil,
        totalCostLimit: Int? = nil
    ) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.insertCount = insertCount
        self.evictionCount = evictionCount
        self.currentEntryCount = currentEntryCount
        self.currentCost = currentCost
        self.countLimit = countLimit
        self.totalCostLimit = totalCostLimit
    }

    public var lookupCount: Int {
        hitCount + missCount
    }

    public var hitRate: Double {
        guard lookupCount > 0 else {
            return 0
        }
        return Double(hitCount) / Double(lookupCount)
    }

    public var missRate: Double {
        guard lookupCount > 0 else {
            return 0
        }
        return Double(missCount) / Double(lookupCount)
    }
}

final class CostBoundCache<Key: Hashable, Value> {
    private struct Entry {
        var value: Value
        var cost: Int
        var accessOrdinal: UInt64
    }

    private let lock = NSLock()
    private let countLimit: Int?
    private let totalCostLimit: Int?
    private let cost: (Value) -> Int

    private var storage: [Key: Entry] = [:]
    private var totalCost = 0
    private var accessOrdinal: UInt64 = 0

    private var hitCount = 0
    private var missCount = 0
    private var insertCount = 0
    private var evictionCount = 0

    init(countLimit: Int? = nil, totalCostLimit: Int? = nil, cost: @escaping (Value) -> Int) {
        self.countLimit = countLimit
        self.totalCostLimit = totalCostLimit
        self.cost = cost
    }

    func value(forKey key: Key) -> Value? {
        lock.withLock {
            guard var entry = storage[key] else {
                missCount += 1
                return nil
            }

            accessOrdinal &+= 1
            entry.accessOrdinal = accessOrdinal
            storage[key] = entry
            hitCount += 1
            return entry.value
        }
    }

    func peekValue(forKey key: Key) -> Value? {
        lock.withLock {
            storage[key]?.value
        }
    }

    func insert(_ value: Value, forKey key: Key) {
        lock.withLock {
            accessOrdinal &+= 1
            let resolvedCost = max(cost(value), 1)

            if let existing = storage.removeValue(forKey: key) {
                totalCost -= existing.cost
            }

            storage[key] = Entry(value: value, cost: resolvedCost, accessOrdinal: accessOrdinal)
            totalCost += resolvedCost
            insertCount += 1
            trimLocked(countLimit: countLimit, totalCostLimit: totalCostLimit)
        }
    }

    func removeValue(forKey key: Key) {
        lock.withLock {
            guard let removed = storage.removeValue(forKey: key) else {
                return
            }
            totalCost -= removed.cost
        }
    }

    func removeAll(where shouldRemove: (Key, Value) -> Bool) {
        lock.withLock {
            let keysToRemove = storage.compactMap { key, entry in
                shouldRemove(key, entry.value) ? key : nil
            }

            for key in keysToRemove {
                guard let removed = storage.removeValue(forKey: key) else {
                    continue
                }
                totalCost -= removed.cost
            }
        }
    }

    func trim(countLimit: Int? = nil, totalCostLimit: Int? = nil) {
        lock.withLock {
            trimLocked(countLimit: countLimit, totalCostLimit: totalCostLimit)
        }
    }

    func removeAll() {
        lock.withLock {
            storage.removeAll(keepingCapacity: false)
            totalCost = 0
        }
    }

    var snapshot: CacheDiagnosticsSnapshot {
        lock.withLock {
            CacheDiagnosticsSnapshot(
                hitCount: hitCount,
                missCount: missCount,
                insertCount: insertCount,
                evictionCount: evictionCount,
                currentEntryCount: storage.count,
                currentCost: totalCost,
                countLimit: countLimit,
                totalCostLimit: totalCostLimit
            )
        }
    }

    private func trimLocked(countLimit: Int?, totalCostLimit: Int?) {
        let resolvedCountLimit = countLimit.map { max($0, 0) }
        let resolvedCostLimit = totalCostLimit.map { max($0, 0) }

        guard resolvedCountLimit != nil || resolvedCostLimit != nil else {
            return
        }

        while exceedsLimit(countLimit: resolvedCountLimit, totalCostLimit: resolvedCostLimit) {
            guard let candidate = storage.min(by: { lhs, rhs in
                lhs.value.accessOrdinal < rhs.value.accessOrdinal
            }) else {
                break
            }

            storage.removeValue(forKey: candidate.key)
            totalCost -= candidate.value.cost
            evictionCount += 1
        }
    }

    private func exceedsLimit(countLimit: Int?, totalCostLimit: Int?) -> Bool {
        if let countLimit, storage.count > countLimit {
            return true
        }

        if let totalCostLimit, totalCost > totalCostLimit {
            return true
        }

        return false
    }
}
