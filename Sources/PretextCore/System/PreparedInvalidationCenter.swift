import Foundation

public enum PreparedInvalidationReason: String, Hashable, Sendable {
    case manual
    case memoryWarning
    case backgroundTrim
    case contentSizeCategoryChanged
    case localeChanged
    case fontSetChanged
    case attachmentMetricsChanged
    case measurementPolicyChanged
}

public enum PreparedInvalidationScope: Hashable, Sendable {
    case all
    case sourceIDs(Set<PreparedTextSourceID>)
    case backgroundTrim
}

public struct PreparedInvalidationRequest: Hashable, Sendable {
    public var scope: PreparedInvalidationScope
    public var reason: PreparedInvalidationReason

    public init(scope: PreparedInvalidationScope, reason: PreparedInvalidationReason) {
        self.scope = scope
        self.reason = reason
    }
}

public final class PreparedInvalidationCenter: @unchecked Sendable {
    public static let shared = PreparedInvalidationCenter()

    static let notificationName = Notification.Name("PreparedTextInvalidationCenter.request")
    static let requestUserInfoKey = "request"

    private let notificationCenter: NotificationCenter

    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    var observerNotificationCenter: NotificationCenter {
        notificationCenter
    }

    public func post(_ request: PreparedInvalidationRequest) {
        notificationCenter.post(
            name: Self.notificationName,
            object: self,
            userInfo: [Self.requestUserInfoKey: request]
        )
    }

    public func invalidateAll(reason: PreparedInvalidationReason = .manual) {
        post(.init(scope: .all, reason: reason))
    }

    public func invalidate(sourceIDs: Set<PreparedTextSourceID>, reason: PreparedInvalidationReason = .manual) {
        guard !sourceIDs.isEmpty else {
            return
        }
        post(.init(scope: .sourceIDs(sourceIDs), reason: reason))
    }

    public func trimForBackground(reason: PreparedInvalidationReason = .backgroundTrim) {
        post(.init(scope: .backgroundTrim, reason: reason))
    }
}
