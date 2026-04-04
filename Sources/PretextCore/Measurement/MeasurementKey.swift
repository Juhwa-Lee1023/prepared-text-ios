import Foundation

enum CacheIdentity: Hashable, Sendable {
    case attributed(AttributedTextLayoutSignature)
    case sourceID(PreparedTextSourceID, AttributedTextLayoutSignature)

    var sourceID: PreparedTextSourceID? {
        switch self {
        case .attributed:
            return nil
        case let .sourceID(sourceID, _):
            return sourceID
        }
    }

    var signature: AttributedTextLayoutSignature {
        switch self {
        case let .attributed(signature):
            return signature
        case let .sourceID(_, signature):
            return signature
        }
    }
}

struct MeasurementCacheContext: Hashable, Sendable {
    var scaleKey: Int
    var measurementOptions: PreparedTextMeasurementOptions

    init(env: MeasurementEnv) {
        scaleKey = env.cacheScalarKey(CGFloat(env.resolvedScale))
        measurementOptions = env.measurementOptions
    }
}

public struct MeasurementKey: Hashable, Sendable {
    var identity: CacheIdentity
    public var widthInPixels: Int
    var context: MeasurementCacheContext

    init(identity: CacheIdentity, widthInPixels: Int, env: MeasurementEnv) {
        self.identity = identity
        self.widthInPixels = widthInPixels
        self.context = MeasurementCacheContext(env: env)
    }
}

struct PreparedTextCacheKey: Hashable, Sendable {
    var identity: CacheIdentity
    var whiteSpaceMode: WhiteSpaceMode
    var localeIdentifier: String?
}

struct PreparedTextOptionsCacheContext: Hashable, Sendable {
    var whiteSpaceMode: WhiteSpaceMode
    var localeIdentifier: String?

    init(options: PreparedTextOptions) {
        whiteSpaceMode = options.whiteSpaceMode
        localeIdentifier = options.localeIdentifier
    }
}

struct SegmentMeasurementKey: Hashable, Sendable {
    var identity: CacheIdentity
}

struct LayoutPacketKey: Hashable, Sendable {
    var identity: CacheIdentity
    var widthInPixels: Int
    var lineHeightKey: Int
    var context: MeasurementCacheContext
    var preparedTextOptions: PreparedTextOptionsCacheContext
    var layoutOptions: PreparedTextLayoutOptions
}
