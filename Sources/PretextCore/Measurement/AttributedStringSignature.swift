import CoreText
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension NSAttributedString {
    func pretextPayloadHash() -> Int {
        var hasher = Hasher()
        hasher.combine(string)
        hasher.combine(length)
        return hasher.finalize()
    }

    func pretextRunSignatureHash() -> Int {
        var hasher = Hasher()
        hasher.combine(length)
        enumerateAttributes(in: NSRange(location: 0, length: length), options: []) { attributes, range, _ in
            hasher.combine(range.location)
            hasher.combine(range.length)
            let pairs = attributes
                .map { ($0.key.rawValue, Self.signature(for: $0.key, value: $0.value)) }
                .sorted { lhs, rhs in
                    if lhs.0 == rhs.0 {
                        return lhs.1 < rhs.1
                    }
                    return lhs.0 < rhs.0
                }

            for pair in pairs {
                hasher.combine(pair.0)
                hasher.combine(pair.1)
            }
        }
        return hasher.finalize()
    }

    private static func signature(for key: NSAttributedString.Key, value: Any) -> String {
        if key.rawValue == (kCTFontAttributeName as NSAttributedString.Key).rawValue {
            return ctFontSignature(value)
        }

        #if canImport(UIKit)
        if let font = value as? UIFont {
            let symbolicTraits = font.fontDescriptor.symbolicTraits.rawValue
            return "uifont:\(font.fontName):\(font.pointSize):\(symbolicTraits)"
        }
        #elseif canImport(AppKit)
        if let font = value as? NSFont {
            let symbolicTraits = font.fontDescriptor.symbolicTraits.rawValue
            return "nsfont:\(font.fontName):\(font.pointSize):\(symbolicTraits)"
        }
        #endif

        if let paragraphStyle = value as? NSParagraphStyle {
            let tabs = paragraphStyle.tabStops.map(\.location)
            return [
                "paragraph",
                "alignment=\(paragraphStyle.alignment.rawValue)",
                "lineSpacing=\(paragraphStyle.lineSpacing)",
                "paragraphSpacing=\(paragraphStyle.paragraphSpacing)",
                "minimumLineHeight=\(paragraphStyle.minimumLineHeight)",
                "maximumLineHeight=\(paragraphStyle.maximumLineHeight)",
                "lineHeightMultiple=\(paragraphStyle.lineHeightMultiple)",
                "headIndent=\(paragraphStyle.headIndent)",
                "tailIndent=\(paragraphStyle.tailIndent)",
                "firstLineHeadIndent=\(paragraphStyle.firstLineHeadIndent)",
                "baseWritingDirection=\(paragraphStyle.baseWritingDirection.rawValue)",
                "lineBreakMode=\(paragraphStyle.lineBreakMode.rawValue)",
                "tabs=\(tabs)",
            ].joined(separator: ";")
        }

        if let number = value as? NSNumber {
            return "number:\(number)"
        }

        if let string = value as? String {
            return "string:\(string)"
        }

        #if canImport(UIKit)
        if let color = value as? UIColor {
            return colorSignature(color)
        }
        #elseif canImport(AppKit)
        if let color = value as? NSColor {
            return colorSignature(color)
        }
        #endif

        if let shadow = value as? NSShadow {
            return shadowSignature(shadow)
        }

        if let attachment = value as? NSTextAttachment {
            return attachmentSignature(attachment)
        }

        if let object = value as? NSObject {
            return objectSignature(object)
        }

        return String(describing: value)
    }

    private static func ctFontSignature(_ value: Any) -> String {
        let object = value as AnyObject
        let font = unsafeDowncast(object, to: CTFont.self)
        let name = CTFontCopyPostScriptName(font) as String
        let size = CTFontGetSize(font)
        let traits = CTFontGetSymbolicTraits(font)
        return "ctfont:\(name):\(size):\(traits.rawValue)"
    }

    #if canImport(UIKit)
    private static func colorSignature(_ color: UIColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return "uicolor:r=\(red),g=\(green),b=\(blue),a=\(alpha)"
        }

        let components = color.cgColor.components ?? []
        return "uicolor:components=\(components)"
    }
    #elseif canImport(AppKit)
    private static func colorSignature(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        return "nscolor:r=\(rgb.redComponent),g=\(rgb.greenComponent),b=\(rgb.blueComponent),a=\(rgb.alphaComponent)"
    }
    #endif

    private static func shadowSignature(_ shadow: NSShadow) -> String {
        let offset = shadow.shadowOffset
        let blur = shadow.shadowBlurRadius
        let colorPart: String
        #if canImport(UIKit)
        if let shadowColor = shadow.shadowColor as? NSObject {
            colorPart = objectSignature(shadowColor)
        } else {
            colorPart = "nil"
        }
        #elseif canImport(AppKit)
        if let shadowColor = shadow.shadowColor {
            colorPart = objectSignature(shadowColor)
        } else {
            colorPart = "nil"
        }
        #else
        colorPart = "nil"
        #endif
        return "shadow:offset=\(offset.width),\(offset.height);blur=\(blur);color=\(colorPart)"
    }

    private static func attachmentSignature(_ attachment: NSTextAttachment) -> String {
        let bounds = attachment.bounds
        var parts = [
            "attachment",
            "bounds=\(bounds.origin.x),\(bounds.origin.y),\(bounds.size.width),\(bounds.size.height)",
        ]

        if let image = attachment.image {
            parts.append("imageSize=\(image.size.width)x\(image.size.height)")
        }

        #if canImport(UIKit)
        if let data = attachment.fileWrapper?.regularFileContents {
            parts.append("fileSize=\(data.count)")
        }
        #elseif canImport(AppKit)
        if let data = attachment.fileWrapper?.regularFileContents {
            parts.append("fileSize=\(data.count)")
        }
        #endif

        return parts.joined(separator: ";")
    }

    private static func objectSignature(_ object: NSObject) -> String {
        let typeName = String(describing: type(of: object))

        if let data = try? NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false) {
            var hasher = Hasher()
            hasher.combine(typeName)
            hasher.combine(data.count)
            hasher.combine(data)
            return "object:\(typeName):\(hasher.finalize())"
        }

        return "objectType:\(typeName)"
    }
}
