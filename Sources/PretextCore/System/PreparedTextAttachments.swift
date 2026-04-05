import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
private func preparedRectValue(_ rect: CGRect) -> NSValue { NSValue(cgRect: rect) }
private func preparedRect(from value: NSValue) -> CGRect { value.cgRectValue }
#elseif canImport(AppKit)
import AppKit
private func preparedRectValue(_ rect: CGRect) -> NSValue { NSValue(rect: rect) }
private func preparedRect(from value: NSValue) -> CGRect { value.rectValue }
#endif

public struct PreparedAttachmentID: RawRepresentable, Hashable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct PreparedAttachmentReference: Hashable, Sendable {
    public var id: PreparedAttachmentID
    public var placeholderBounds: CGRect

    public init(id: PreparedAttachmentID, placeholderBounds: CGRect = .zero) {
        self.id = id
        self.placeholderBounds = placeholderBounds
    }
}

public struct PreparedResolvedAttachment: Hashable, Sendable {
    public var bounds: CGRect
    public var contentIdentity: String?

    public init(bounds: CGRect, contentIdentity: String? = nil) {
        self.bounds = bounds
        self.contentIdentity = contentIdentity
    }
}

public enum PreparedAttachmentLifecycleState: Hashable, Sendable {
    case placeholder(PreparedAttachmentReference)
    case resolved(PreparedAttachmentReference, PreparedResolvedAttachment)

    public var reference: PreparedAttachmentReference {
        switch self {
        case let .placeholder(reference), let .resolved(reference, _):
            return reference
        }
    }

    public var resolvedAttachment: PreparedResolvedAttachment? {
        switch self {
        case .placeholder:
            return nil
        case let .resolved(_, resolvedAttachment):
            return resolvedAttachment
        }
    }

    public var resolvedBounds: CGRect {
        resolvedAttachment?.bounds ?? reference.placeholderBounds
    }
}

public protocol PreparedAttachmentResolving: AnyObject, Sendable {
    func resolvedAttachment(for reference: PreparedAttachmentReference) -> PreparedResolvedAttachment?
}

public protocol PreparedAttachmentResolver: PreparedAttachmentResolving {
    func attachmentState(for reference: PreparedAttachmentReference) -> PreparedAttachmentLifecycleState
}

public extension PreparedAttachmentResolver {
    func resolvedAttachment(for reference: PreparedAttachmentReference) -> PreparedResolvedAttachment? {
        attachmentState(for: reference).resolvedAttachment
    }
}

public extension NSAttributedString.Key {
    static let preparedAttachmentReference = NSAttributedString.Key("PreparedTextAttachmentReference")
    static let preparedResolvedAttachmentIdentity = NSAttributedString.Key("PreparedTextResolvedAttachmentIdentity")
}

public final class PreparedTextAttachment: NSTextAttachment {
    public var reference: PreparedAttachmentReference

    public init(reference: PreparedAttachmentReference) {
        self.reference = reference
        super.init(data: nil, ofType: nil)
        bounds = reference.placeholderBounds
    }

    public required init?(coder: NSCoder) {
        guard let rawID = coder.decodeObject(forKey: "preparedAttachmentID") as? NSString else {
            return nil
        }

        let rect = (coder.decodeObject(forKey: "preparedAttachmentPlaceholderBounds") as? NSValue)
            .map(preparedRect(from:))
            ?? .zero
        reference = PreparedAttachmentReference(
            id: PreparedAttachmentID(rawID as String),
            placeholderBounds: rect
        )
        super.init(coder: coder)
        bounds = reference.placeholderBounds
    }

    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(reference.id.rawValue as NSString, forKey: "preparedAttachmentID")
        coder.encode(preparedRectValue(reference.placeholderBounds), forKey: "preparedAttachmentPlaceholderBounds")
    }
}

public final class PreparedAttachmentRegistry: @unchecked Sendable, PreparedAttachmentResolver {
    public static let shared = PreparedAttachmentRegistry()

    private let lock = NSLock()
    private let invalidationCenter: PreparedInvalidationCenter
    private var resolvedAttachments: [PreparedAttachmentID: PreparedResolvedAttachment] = [:]
    private var recordedSourceUsage: [PreparedAttachmentID: Set<PreparedTextSourceID>] = [:]
    private var recordedAttachmentsBySource: [PreparedTextSourceID: Set<PreparedAttachmentID>] = [:]

    public init(invalidationCenter: PreparedInvalidationCenter = .shared) {
        self.invalidationCenter = invalidationCenter
    }

    public func resolvedAttachment(for reference: PreparedAttachmentReference) -> PreparedResolvedAttachment? {
        lock.withLock {
            resolvedAttachments[reference.id]
        }
    }

    public func attachmentState(for reference: PreparedAttachmentReference) -> PreparedAttachmentLifecycleState {
        if let resolvedAttachment = resolvedAttachment(for: reference) {
            return .resolved(reference, resolvedAttachment)
        }
        return .placeholder(reference)
    }

    public func setAttachmentState(
        _ state: PreparedAttachmentLifecycleState,
        invalidate sourceIDs: Set<PreparedTextSourceID>? = nil
    ) {
        switch state {
        case let .placeholder(reference):
            setResolvedAttachment(nil, for: reference.id, invalidate: sourceIDs)
        case let .resolved(reference, resolvedAttachment):
            setResolvedAttachment(resolvedAttachment, for: reference.id, invalidate: sourceIDs)
        }
    }

    public func setResolvedAttachment(
        _ resolvedAttachment: PreparedResolvedAttachment?,
        for id: PreparedAttachmentID,
        invalidate sourceIDs: Set<PreparedTextSourceID>? = nil
    ) {
        let recordedSourceIDs = lock.withLock { () -> Set<PreparedTextSourceID> in
            if let resolvedAttachment {
                resolvedAttachments[id] = resolvedAttachment
            } else {
                resolvedAttachments.removeValue(forKey: id)
            }
            return recordedSourceUsage[id] ?? []
        }

        let targetSourceIDs = sourceIDs ?? recordedSourceIDs
        if sourceIDs == nil && targetSourceIDs.isEmpty {
            return
        }

        if targetSourceIDs.isEmpty {
            invalidationCenter.invalidateAll(reason: .attachmentMetricsChanged)
        } else {
            invalidationCenter.invalidate(sourceIDs: targetSourceIDs, reason: .attachmentMetricsChanged)
        }
    }

    public func removeResolvedAttachment(
        for id: PreparedAttachmentID,
        invalidate sourceIDs: Set<PreparedTextSourceID>? = nil
    ) {
        setResolvedAttachment(nil, for: id, invalidate: sourceIDs)
    }

    public func recordedSourceIDs(for id: PreparedAttachmentID) -> Set<PreparedTextSourceID> {
        lock.withLock {
            recordedSourceUsage[id] ?? []
        }
    }

    public func invalidateRecordedSources(
        for attachmentIDs: Set<PreparedAttachmentID>,
        reason: PreparedInvalidationReason = .attachmentMetricsChanged
    ) {
        let sourceIDs = lock.withLock {
            attachmentIDs.reduce(into: Set<PreparedTextSourceID>()) { partialResult, attachmentID in
                partialResult.formUnion(recordedSourceUsage[attachmentID] ?? [])
            }
        }

        guard sourceIDs.isEmpty == false else {
            return
        }

        invalidationCenter.invalidate(sourceIDs: sourceIDs, reason: reason)
    }

    func recordUsage(of attachmentIDs: Set<PreparedAttachmentID>, sourceID: PreparedTextSourceID?) {
        guard let sourceID else {
            return
        }

        lock.withLock {
            let previousAttachmentIDs = recordedAttachmentsBySource[sourceID] ?? []

            for attachmentID in previousAttachmentIDs.subtracting(attachmentIDs) {
                var sourceIDs = recordedSourceUsage[attachmentID] ?? []
                sourceIDs.remove(sourceID)
                if sourceIDs.isEmpty {
                    recordedSourceUsage.removeValue(forKey: attachmentID)
                } else {
                    recordedSourceUsage[attachmentID] = sourceIDs
                }
            }

            for attachmentID in attachmentIDs {
                recordedSourceUsage[attachmentID, default: []].insert(sourceID)
            }

            if attachmentIDs.isEmpty {
                recordedAttachmentsBySource.removeValue(forKey: sourceID)
            } else {
                recordedAttachmentsBySource[sourceID] = attachmentIDs
            }
        }
    }
}

extension NSAttributedString {
    func preparedAttachmentReferences() -> Set<PreparedAttachmentID> {
        guard length > 0 else {
            return []
        }

        var ids: Set<PreparedAttachmentID> = []
        enumerateAttributes(in: NSRange(location: 0, length: length), options: []) { attributes, _, _ in
            if let reference = attributes[.preparedAttachmentReference] as? PreparedAttachmentReference {
                ids.insert(reference.id)
            }
            if let attachment = attributes[.attachment] as? PreparedTextAttachment {
                ids.insert(attachment.reference.id)
            }
        }
        return ids
    }
}
