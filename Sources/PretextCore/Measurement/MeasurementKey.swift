import Foundation

enum CacheIdentity: Hashable, Sendable {
    case attributed(payloadHash: Int, runSignatureHash: Int)
    case sourceID(PreparedTextSourceID)

    var requiresSourceValidation: Bool {
        switch self {
        case .attributed:
            return false
        case .sourceID:
            return true
        }
    }
}

public struct MeasurementKey: Hashable, Sendable {
    var identity: CacheIdentity
    public var widthInPixels: Int
    public var env: MeasurementEnv

    public init(
        payloadHash: Int,
        runSignatureHash: Int,
        widthInPixels: Int,
        env: MeasurementEnv
    ) {
        self.identity = .attributed(payloadHash: payloadHash, runSignatureHash: runSignatureHash)
        self.widthInPixels = widthInPixels
        self.env = env
    }

    init(identity: CacheIdentity, widthInPixels: Int, env: MeasurementEnv) {
        self.identity = identity
        self.widthInPixels = widthInPixels
        self.env = env
    }
}

struct PreparedTextCacheKey: Hashable {
    var identity: CacheIdentity
    var optionsHash: Int
}

struct SegmentMeasurementKey: Hashable {
    var identity: CacheIdentity
}

struct LayoutPacketKey: Hashable {
    var preparedIdentity: ObjectIdentifier
    var widthInPixels: Int
    var lineHeightInPixels: Int
    var layoutDirectionPlaceholder: String?
    var maxLines: Int?
    var truncationModeIdentifier: String?
}
