import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum PreparedTokenKind: String, Hashable, Sendable {
    case word
    case cjkRun
    case urlLike
    case mention
    case hashtag
    case attachment
}

public struct PreparedToken: Hashable, Sendable {
    public var kind: PreparedTokenKind
    public var sourceUTF16Range: NSRange
    public var sourceText: String
    public var attachmentReference: PreparedAttachmentReference?

    public init(
        kind: PreparedTokenKind,
        sourceUTF16Range: NSRange,
        sourceText: String,
        attachmentReference: PreparedAttachmentReference? = nil
    ) {
        self.kind = kind
        self.sourceUTF16Range = sourceUTF16Range
        self.sourceText = sourceText
        self.attachmentReference = attachmentReference
    }
}

public enum PreparedAnnotationKind: String, Hashable, Sendable {
    case link
    case mention
    case hashtag
    case attachment
}

public struct PreparedAnnotation: Hashable, Sendable {
    public var kind: PreparedAnnotationKind
    public var sourceUTF16Range: NSRange
    public var sourceText: String
    public var linkDestination: String?
    public var attachmentReference: PreparedAttachmentReference?

    public init(
        kind: PreparedAnnotationKind,
        sourceUTF16Range: NSRange,
        sourceText: String,
        linkDestination: String? = nil,
        attachmentReference: PreparedAttachmentReference? = nil
    ) {
        self.kind = kind
        self.sourceUTF16Range = sourceUTF16Range
        self.sourceText = sourceText
        self.linkDestination = linkDestination
        self.attachmentReference = attachmentReference
    }
}

public struct PreparedAttachmentSpan: Hashable, Sendable {
    public var sourceUTF16Range: NSRange
    public var sourceText: String
    public var reference: PreparedAttachmentReference
    public var resolvedBounds: CGRect
    public var resolvedContentIdentity: String?

    public init(
        sourceUTF16Range: NSRange,
        sourceText: String,
        reference: PreparedAttachmentReference,
        resolvedBounds: CGRect,
        resolvedContentIdentity: String?
    ) {
        self.sourceUTF16Range = sourceUTF16Range
        self.sourceText = sourceText
        self.reference = reference
        self.resolvedBounds = resolvedBounds
        self.resolvedContentIdentity = resolvedContentIdentity
    }

    public var isResolved: Bool {
        resolvedContentIdentity != nil || resolvedBounds != reference.placeholderBounds
    }
}

public extension PreparedText {
    var attachmentSpans: [PreparedAttachmentSpan] {
        guard source.length > 0 else {
            return []
        }

        var spans: [PreparedAttachmentSpan] = []
        source.enumerateAttributes(in: NSRange(location: 0, length: source.length), options: []) { attributes, range, _ in
            guard range.length > 0 else {
                return
            }

            let reference = (attributes[.preparedAttachmentReference] as? PreparedAttachmentReference)
                ?? (attributes[.attachment] as? PreparedTextAttachment)?.reference
            guard let reference else {
                return
            }

            let resolvedBounds = (attributes[.attachment] as? NSTextAttachment)?.bounds ?? reference.placeholderBounds
            let resolvedContentIdentity = attributes[.preparedResolvedAttachmentIdentity] as? String
            spans.append(
                PreparedAttachmentSpan(
                    sourceUTF16Range: range,
                    sourceText: source.attributedSubstring(from: range).string,
                    reference: reference,
                    resolvedBounds: resolvedBounds,
                    resolvedContentIdentity: resolvedContentIdentity
                )
            )
        }

        return spans.sorted { lhs, rhs in
            if lhs.sourceUTF16Range.location == rhs.sourceUTF16Range.location {
                return lhs.sourceUTF16Range.length < rhs.sourceUTF16Range.length
            }
            return lhs.sourceUTF16Range.location < rhs.sourceUTF16Range.location
        }
    }

    var tokens: [PreparedToken] {
        let attachments = attachmentSpans
        var seenAttachmentRanges = Set<PreparedRangeKey>()
        var tokens: [PreparedToken] = []
        var location = 0

        for segment in storage.core.segments {
            let length = segment.string.utf16.count
            let sourceRange = NSRange(location: location, length: length)
            location += length

            guard sourceRange.length > 0 else {
                continue
            }

            if let attachment = attachments.first(where: { preparedRangesOverlap($0.sourceUTF16Range, sourceRange) }) {
                let key = PreparedRangeKey(range: attachment.sourceUTF16Range)
                if seenAttachmentRanges.insert(key).inserted {
                    tokens.append(
                        PreparedToken(
                            kind: .attachment,
                            sourceUTF16Range: attachment.sourceUTF16Range,
                            sourceText: attachment.sourceText,
                            attachmentReference: attachment.reference
                        )
                    )
                }
                continue
            }

            guard let tokenKind = preparedPublicTokenKind(for: segment) else {
                continue
            }

            let sourceText = source.attributedSubstring(from: sourceRange).string
            tokens.append(
                PreparedToken(
                    kind: tokenKind,
                    sourceUTF16Range: sourceRange,
                    sourceText: sourceText
                )
            )
        }

        return tokens.sorted { lhs, rhs in
            if lhs.sourceUTF16Range.location == rhs.sourceUTF16Range.location {
                return lhs.sourceUTF16Range.length < rhs.sourceUTF16Range.length
            }
            return lhs.sourceUTF16Range.location < rhs.sourceUTF16Range.location
        }
    }

    var annotations: [PreparedAnnotation] {
        var annotations: [PreparedAnnotation] = []

        if source.length > 0 {
            source.enumerateAttribute(.link, in: NSRange(location: 0, length: source.length), options: []) { value, range, _ in
                guard value != nil, range.length > 0 else {
                    return
                }

                annotations.append(
                    PreparedAnnotation(
                        kind: .link,
                        sourceUTF16Range: range,
                        sourceText: source.attributedSubstring(from: range).string,
                        linkDestination: preparedLinkDestination(from: value)
                    )
                )
            }
        }

        for token in tokens {
            switch token.kind {
            case .mention:
                annotations.append(
                    PreparedAnnotation(
                        kind: .mention,
                        sourceUTF16Range: token.sourceUTF16Range,
                        sourceText: token.sourceText
                    )
                )
            case .hashtag:
                annotations.append(
                    PreparedAnnotation(
                        kind: .hashtag,
                        sourceUTF16Range: token.sourceUTF16Range,
                        sourceText: token.sourceText
                    )
                )
            case .attachment:
                annotations.append(
                    PreparedAnnotation(
                        kind: .attachment,
                        sourceUTF16Range: token.sourceUTF16Range,
                        sourceText: token.sourceText,
                        attachmentReference: token.attachmentReference
                    )
                )
            case .word, .cjkRun, .urlLike:
                break
            }
        }

        return annotations.sorted { lhs, rhs in
            if lhs.sourceUTF16Range.location == rhs.sourceUTF16Range.location {
                if lhs.sourceUTF16Range.length == rhs.sourceUTF16Range.length {
                    return preparedAnnotationSortPriority(lhs.kind) < preparedAnnotationSortPriority(rhs.kind)
                }
                return lhs.sourceUTF16Range.length < rhs.sourceUTF16Range.length
            }
            return lhs.sourceUTF16Range.location < rhs.sourceUTF16Range.location
        }
    }
}

public extension PreparedLayoutPacket {
    func visibleTokens(in prepared: PreparedText) -> [PreparedToken] {
        sourceCoordinateMap.visibleTokens(in: prepared)
    }

    func visibleAnnotations(in prepared: PreparedText) -> [PreparedAnnotation] {
        sourceCoordinateMap.visibleAnnotations(in: prepared)
    }

    func visibleAttachmentSpans(in prepared: PreparedText) -> [PreparedAttachmentSpan] {
        sourceCoordinateMap.visibleAttachmentSpans(in: prepared)
    }
}

public extension PreparedTextDisplayPacket {
    func visibleTokens(in prepared: PreparedText) -> [PreparedToken] {
        sourceCoordinateMap.visibleTokens(in: prepared)
    }

    func visibleAnnotations(in prepared: PreparedText) -> [PreparedAnnotation] {
        sourceCoordinateMap.visibleAnnotations(in: prepared)
    }

    func visibleAttachmentSpans(in prepared: PreparedText) -> [PreparedAttachmentSpan] {
        sourceCoordinateMap.visibleAttachmentSpans(in: prepared)
    }
}

private struct PreparedRangeKey: Hashable {
    var location: Int
    var length: Int

    init(range: NSRange) {
        location = range.location
        length = range.length
    }
}

private func preparedRangesOverlap(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
    NSIntersectionRange(lhs, rhs).length > 0
}

private func preparedPublicTokenKind(for segment: PreparedSegment) -> PreparedTokenKind? {
    switch segment.kind {
    case .word, .glue:
        return .word
    case .cjkRun:
        return .cjkRun
    case .urlLike:
        if segment.string.hasPrefix("@"), segment.string.utf16.count > 1 {
            return .mention
        }
        if segment.string.hasPrefix("#"), segment.string.utf16.count > 1 {
            return .hashtag
        }
        return .urlLike
    case .punctuationPrefix, .punctuationSuffix, .whitespace, .tab, .softHyphen, .zeroWidthBreak, .hardBreak:
        return nil
    }
}

private func preparedLinkDestination(from value: Any?) -> String? {
    switch value {
    case let url as URL:
        return url.absoluteString
    case let string as String:
        return string
    case let string as NSString:
        return string as String
    default:
        return nil
    }
}

private func preparedAnnotationSortPriority(_ kind: PreparedAnnotationKind) -> Int {
    switch kind {
    case .link:
        return 0
    case .mention:
        return 1
    case .hashtag:
        return 2
    case .attachment:
        return 3
    }
}
