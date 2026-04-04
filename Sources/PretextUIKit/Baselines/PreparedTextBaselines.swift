#if canImport(UIKit) && !os(macOS)
import PretextCore
@preconcurrency import UIKit

@MainActor
private func normalizedBaselineAttributedText(for label: UILabel, fixture: CorrectnessFixture) -> NSAttributedString {
    let mutable = NSMutableAttributedString(attributedString: fixture.text)
    let fullRange = NSRange(location: 0, length: mutable.length)

    mutable.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
        let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.lineBreakMode = label.lineBreakMode
        mutable.addAttribute(.paragraphStyle, value: style, range: range)
    }

    return mutable
}

private func runOnMain<T: Sendable>(_ body: @MainActor () -> T) -> T {
    if Thread.isMainThread {
        return MainActor.assumeIsolated {
            body()
        }
    }

    return DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            body()
        }
    }
}

public struct UILabelComparator: TextBaselineComparator, Sendable {
    public let name = "UILabel"
    public var numberOfLines: Int
    public var lineBreakMode: NSLineBreakMode

    public init(numberOfLines: Int = 0, lineBreakMode: NSLineBreakMode = .byWordWrapping) {
        self.numberOfLines = numberOfLines
        self.lineBreakMode = lineBreakMode
    }

    public func snapshot(for fixture: CorrectnessFixture, width: CGFloat) -> BaselineSnapshot {
        runOnMain {
            let label = UILabel()
            label.numberOfLines = numberOfLines
            label.lineBreakMode = lineBreakMode
            label.preferredMaxLayoutWidth = width
            label.bounds.size.width = width
            label.attributedText = fixture.text
            let size = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))

            let lines = TextKitLineExtractor.extractLines(
                from: normalizedBaselineAttributedText(for: label, fixture: fixture),
                width: width,
                lineFragmentPadding: 0,
                lineBreakMode: lineBreakMode,
                maximumNumberOfLines: numberOfLines
            )

            return BaselineSnapshot(
                baselineName: name,
                fixtureID: fixture.id,
                width: width,
                lineCount: lines.count,
                height: size.height,
                lines: lines
            )
        }
    }
}

public struct UITextViewComparator: TextBaselineComparator, Sendable {
    public let name = "UITextView"

    public init() {}

    public func snapshot(for fixture: CorrectnessFixture, width: CGFloat) -> BaselineSnapshot {
        runOnMain {
            let textView = UITextView()
            textView.isScrollEnabled = false
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.attributedText = fixture.text
            textView.bounds.size.width = width
            let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            textView.layoutManager.ensureLayout(for: textView.textContainer)

            let lines = TextKitLineExtractor.extractLines(
                using: textView.layoutManager,
                textContainer: textView.textContainer,
                string: textView.attributedText?.string ?? fixture.text.string
            )

            return BaselineSnapshot(
                baselineName: name,
                fixtureID: fixture.id,
                width: width,
                lineCount: lines.count,
                height: size.height,
                lines: lines
            )
        }
    }
}

private enum TextKitLineExtractor {
    static func extractLines(
        from attributedText: NSAttributedString,
        width: CGFloat,
        lineFragmentPadding: CGFloat,
        lineBreakMode: NSLineBreakMode = .byWordWrapping,
        maximumNumberOfLines: Int = 0
    ) -> [BaselineLineSnapshot] {
        let storage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = lineFragmentPadding
        container.lineBreakMode = lineBreakMode
        container.maximumNumberOfLines = maximumNumberOfLines
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        return extractLines(using: layoutManager, textContainer: container, string: attributedText.string)
    }

    static func extractLines(using layoutManager: NSLayoutManager, textContainer: NSTextContainer, string: String) -> [BaselineLineSnapshot] {
        var snapshots: [BaselineLineSnapshot] = []
        var glyphIndex = 0
        let nsString = string as NSString
        let glyphLimit = layoutManager.glyphRange(for: textContainer).upperBound

        while glyphIndex < glyphLimit {
            var lineRange = NSRange(location: 0, length: 0)
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
            let characterRange = layoutManager.characterRange(forGlyphRange: lineRange, actualGlyphRange: nil)
            let text = normalizedSnapshotLineText(nsString.substring(with: characterRange))
            snapshots.append(
                BaselineLineSnapshot(
                    index: snapshots.count,
                    rangeDescription: "\(characterRange.location)..<\(characterRange.location + characterRange.length)",
                    text: text
                )
            )
            glyphIndex = NSMaxRange(lineRange)
        }

        return snapshots
    }
}
#endif
