import Foundation

final class CostBoundCache<Key: Hashable, Value> {
    private let storage = NSCache<CacheKeyBox<Key>, CacheValueBox<Value>>()
    private let cost: (Value) -> Int

    init(countLimit: Int? = nil, totalCostLimit: Int? = nil, cost: @escaping (Value) -> Int) {
        if let countLimit {
            storage.countLimit = countLimit
        }
        if let totalCostLimit {
            storage.totalCostLimit = totalCostLimit
        }
        self.cost = cost
    }

    func value(forKey key: Key) -> Value? {
        storage.object(forKey: CacheKeyBox(key))?.value
    }

    func insert(_ value: Value, forKey key: Key) {
        storage.setObject(CacheValueBox(value), forKey: CacheKeyBox(key), cost: max(cost(value), 1))
    }

    func removeAll() {
        storage.removeAllObjects()
    }
}

private final class CacheKeyBox<Key: Hashable>: NSObject {
    let key: Key

    init(_ key: Key) {
        self.key = key
    }

    override var hash: Int {
        key.hashValue
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CacheKeyBox<Key> else {
            return false
        }
        return other.key == key
    }
}

private final class CacheValueBox<Value>: NSObject {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
