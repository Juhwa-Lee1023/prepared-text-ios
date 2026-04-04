import CoreText
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AttributedTextLayoutSignature: Hashable, Sendable {
    var payloadDigest: UInt64
    var layoutDigest: UInt64
    var length: Int
    var attributeRunCount: Int
    var attachmentCount: Int
}

private struct StableLayoutHasher {
    private static let offsetBasis: UInt64 = 14_695_981_039_346_656_037
    private static let prime: UInt64 = 1_099_511_628_211

    private var state: UInt64 = offsetBasis

    mutating func combine(_ value: UInt8) {
        state ^= UInt64(value)
        state = state &* Self.prime
    }

    mutating func combine(_ value: Bool) {
        combine(value ? 1 : 0)
    }

    mutating func combine(_ value: UInt64) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { buffer in
            for byte in buffer {
                combine(byte)
            }
        }
    }

    mutating func combine(_ value: Int) {
        combine(UInt64(bitPattern: Int64(value)))
    }

    mutating func combine(_ value: Double) {
        combine(value.bitPattern)
    }

    mutating func combine(_ value: CGFloat) {
        combine(Double(value))
    }

    mutating func combine(_ value: String) {
        combine(value.utf8.count)
        for byte in value.utf8 {
            combine(byte)
        }
    }

    mutating func combine(_ value: Data) {
        combine(value.count)
        value.forEach { combine($0) }
    }

    mutating func combine(_ values: [CGFloat]) {
        combine(values.count)
        values.forEach { combine($0) }
    }

    func finalize() -> UInt64 {
        state
    }
}

extension NSAttributedString {
    func pretextLayoutSignature() -> AttributedTextLayoutSignature {
        var payloadHasher = StableLayoutHasher()
        payloadHasher.combine(string)
        payloadHasher.combine(length)

        var layoutHasher = StableLayoutHasher()
        layoutHasher.combine(length)

        var attributeRunCount = 0
        var attachmentCount = 0

        enumerateAttributes(in: NSRange(location: 0, length: length), options: []) { attributes, range, _ in
            attributeRunCount += 1
            layoutHasher.combine(range.location)
            layoutHasher.combine(range.length)

            let layoutPairs = Self.layoutAffectingAttributes(attributes)
            layoutHasher.combine(layoutPairs.count)
            for pair in layoutPairs {
                layoutHasher.combine(pair.key)
                layoutHasher.combine(pair.signature)
                if pair.key == NSAttributedString.Key.attachment.rawValue {
                    attachmentCount += 1
                }
            }
        }

        return AttributedTextLayoutSignature(
            payloadDigest: payloadHasher.finalize(),
            layoutDigest: layoutHasher.finalize(),
            length: length,
            attributeRunCount: attributeRunCount,
            attachmentCount: attachmentCount
        )
    }

    private static func layoutAffectingAttributes(_ attributes: [NSAttributedString.Key: Any]) -> [(key: String, signature: String)] {
        attributes.compactMap { key, value in
            guard let signature = signature(for: key, value: value) else {
                return nil
            }
            return (key.rawValue, signature)
        }
        .sorted { lhs, rhs in
            if lhs.key == rhs.key {
                return lhs.signature < rhs.signature
            }
            return lhs.key < rhs.key
        }
    }

    private static func signature(for key: NSAttributedString.Key, value: Any) -> String? {
        switch key.rawValue {
        case (kCTFontAttributeName as NSAttributedString.Key).rawValue,
             NSAttributedString.Key.font.rawValue:
            return fontSignature(value)

        case NSAttributedString.Key.paragraphStyle.rawValue:
            guard let paragraphStyle = value as? NSParagraphStyle else {
                return nil
            }
            return paragraphStyleSignature(paragraphStyle)

        case NSAttributedString.Key.kern.rawValue,
             (kCTKernAttributeName as NSAttributedString.Key).rawValue,
             NSAttributedString.Key.baselineOffset.rawValue,
             NSAttributedString.Key.expansion.rawValue,
             NSAttributedString.Key.obliqueness.rawValue,
             NSAttributedString.Key.verticalGlyphForm.rawValue,
             (kCTLigatureAttributeName as NSAttributedString.Key).rawValue,
             NSAttributedString.Key.ligature.rawValue:
            return scalarNumberSignature(value)

        case NSAttributedString.Key.writingDirection.rawValue:
            return writingDirectionSignature(value)

        case NSAttributedString.Key.attachment.rawValue:
            guard let attachment = value as? NSTextAttachment else {
                return nil
            }
            return attachmentSignature(attachment)

        case NSAttributedString.Key.preparedAttachmentReference.rawValue:
            guard let reference = value as? PreparedAttachmentReference else {
                return nil
            }
            return "preparedAttachmentReference:\(reference.id.rawValue):\(reference.placeholderBounds.origin.x):\(reference.placeholderBounds.origin.y):\(reference.placeholderBounds.size.width):\(reference.placeholderBounds.size.height)"

        case NSAttributedString.Key.preparedResolvedAttachmentIdentity.rawValue:
            if let string = value as? String {
                return "preparedResolvedAttachmentIdentity:\(string)"
            }
            return String(describing: value)

        case (kCTLanguageAttributeName as NSAttributedString.Key).rawValue,
             "NSLanguage":
            if let string = value as? String {
                return "language:\(string)"
            }
            return String(describing: value)

        default:
            return nil
        }
    }

    private static func fontSignature(_ value: Any) -> String {
        if let ctFont = ctFont(from: value) {
            let name = CTFontCopyPostScriptName(ctFont) as String
            let size = CTFontGetSize(ctFont)
            let traits = CTFontGetSymbolicTraits(ctFont)
            return "font:\(name):size=\(size):traits=\(traits.rawValue)"
        }

        #if canImport(UIKit)
        if let font = value as? UIFont {
            return "font:\(font.fontName):size=\(font.pointSize):traits=\(font.fontDescriptor.symbolicTraits.rawValue)"
        }
        #elseif canImport(AppKit)
        if let font = value as? NSFont {
            return "font:\(font.fontName):size=\(font.pointSize):traits=\(font.fontDescriptor.symbolicTraits.rawValue)"
        }
        #endif

        return "font:\(String(describing: value))"
    }

    private static func paragraphStyleSignature(_ paragraphStyle: NSParagraphStyle) -> String {
        let tabs = paragraphStyle.tabStops.map(\.location)
        let tabsSignature = tabs.map(String.init).joined(separator: ",")

        var parts = [
            "paragraph",
            "alignment=\(paragraphStyle.alignment.rawValue)",
            "lineBreakMode=\(paragraphStyle.lineBreakMode.rawValue)",
            "baseWritingDirection=\(paragraphStyle.baseWritingDirection.rawValue)",
            "lineSpacing=\(paragraphStyle.lineSpacing)",
            "paragraphSpacingBefore=\(paragraphStyle.paragraphSpacingBefore)",
            "paragraphSpacing=\(paragraphStyle.paragraphSpacing)",
            "minimumLineHeight=\(paragraphStyle.minimumLineHeight)",
            "maximumLineHeight=\(paragraphStyle.maximumLineHeight)",
            "lineHeightMultiple=\(paragraphStyle.lineHeightMultiple)",
            "headIndent=\(paragraphStyle.headIndent)",
            "tailIndent=\(paragraphStyle.tailIndent)",
            "firstLineHeadIndent=\(paragraphStyle.firstLineHeadIndent)",
            "defaultTabInterval=\(paragraphStyle.defaultTabInterval)",
            "hyphenationFactor=\(paragraphStyle.hyphenationFactor)",
            "tabs=\(tabsSignature)",
        ]

        if #available(iOS 14.0, macOS 11.0, *) {
            parts.append("lineBreakStrategy=\(paragraphStyle.lineBreakStrategy.rawValue)")
        }

        return parts.joined(separator: ";")
    }

    private static func scalarNumberSignature(_ value: Any) -> String? {
        if let number = value as? NSNumber {
            return "number:\(number.doubleValue)"
        }

        if let double = value as? Double {
            return "number:\(double)"
        }

        if let float = value as? CGFloat {
            return "number:\(float)"
        }

        return nil
    }

    private static func writingDirectionSignature(_ value: Any) -> String {
        if let array = value as? [Int] {
            let signature = array.map(String.init).joined(separator: ",")
            return "writingDirection:\(signature)"
        }

        if let array = value as? [NSNumber] {
            let signature = array.map { String($0.intValue) }.joined(separator: ",")
            return "writingDirection:\(signature)"
        }

        return "writingDirection:\(String(describing: value))"
    }

    private static func attachmentSignature(_ attachment: NSTextAttachment) -> String {
        var hasher = StableLayoutHasher()
        hasher.combine(String(describing: type(of: attachment)))
        hasher.combine(attachment.bounds.origin.x)
        hasher.combine(attachment.bounds.origin.y)
        hasher.combine(attachment.bounds.size.width)
        hasher.combine(attachment.bounds.size.height)

        if let image = attachment.image {
            hasher.combine(image.size.width)
            hasher.combine(image.size.height)
        }

        if let fileWrapper = attachment.fileWrapper {
            hasher.combine(fileWrapper.filename ?? "")
            if let data = fileWrapper.regularFileContents {
                hasher.combine(data)
            }
        }

        return "attachment:\(hasher.finalize())"
    }

    private static func ctFont(from value: Any) -> CTFont? {
        if CFGetTypeID(value as CFTypeRef) == CTFontGetTypeID() {
            let object = value as AnyObject
            return unsafeDowncast(object, to: CTFont.self)
        }
        return nil
    }
}
