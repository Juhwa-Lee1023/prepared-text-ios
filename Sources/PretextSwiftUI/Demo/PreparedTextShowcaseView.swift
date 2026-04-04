#if canImport(UIKit) && canImport(SwiftUI) && !os(macOS)
import PretextCore
import PretextUIKit
import SwiftUI
import UIKit

public struct PreparedTextShowcaseView: View {
    public let language: PreparedTextDemoLanguage

    public init(language: PreparedTextDemoLanguage = .preferred) {
        self.language = language
    }

    private var copy: PreparedShowcaseCopy {
        PreparedShowcaseCopy(language: language)
    }

    private var samples: [DemoSample] {
        DemoSample.make(language: language)
    }

    private var contractSamples: [WhiteSpaceContractSample] {
        WhiteSpaceContractSample.make(language: language)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ShowcaseHeroSection(copy: copy)
                PreparedCapabilitySummarySection(copy: copy)

                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(
                        eyebrow: copy.realSurfacesEyebrow,
                        title: copy.realSurfacesTitle,
                        detail: copy.realSurfacesDetail
                    )

                    ForEach(samples) { sample in
                        ShowcaseCard(sample: sample, language: language, copy: copy)
                    }
                }

                PreparedInteractiveLinkSection(copy: copy, language: language)
                PreparedWhitespaceContractSection(samples: contractSamples, copy: copy, language: language)

                PreparedWidthLabSection(
                    attributedText: samples[1].text,
                    sourceID: samples[1].sourceID,
                    whiteSpaceMode: samples[1].whiteSpaceMode,
                    tint: samples[1].accentColor,
                    copy: copy,
                    language: language
                )

                PreparedShrinkwrapShowdownSection(copy: copy, language: language)
                PreparedPlayLabSection(copy: copy, language: language)
            }
            .padding(20)
        }
        .background(PreparedShowcasePalette.canvasBackground)
    }
}

private enum PreparedShowcasePalette {
    static let canvasBackground = Color(uiColor: .systemGroupedBackground)
    static let panelBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let insetBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    static let raisedBackground = Color(uiColor: .systemBackground)
    static let softStroke = Color(uiColor: UIColor.separator.withAlphaComponent(0.22))
    static let controlBackground = Color(uiColor: UIColor.secondarySystemGroupedBackground)
    static let floatingBadgeBackground = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.14, alpha: 0.94)
            : UIColor(white: 1.0, alpha: 0.94)
    })
    static let heroStart = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.18, blue: 0.29, alpha: 1.0)
            : UIColor(red: 0.13, green: 0.24, blue: 0.47, alpha: 1.0)
    })
    static let heroEnd = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.28, blue: 0.44, alpha: 1.0)
            : UIColor(red: 0.27, green: 0.45, blue: 0.74, alpha: 1.0)
    })

    static func tint(light: UIColor, dark: UIColor? = nil) -> Color {
        Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark, let dark {
                return dark
            }
            return light
        })
    }

    static func surface(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}

private struct ShowcaseHeroSection: View {
    let copy: PreparedShowcaseCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.22))
                        .frame(width: 56, height: 56)
                    Image(systemName: "text.redaction")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.heroTitle)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text(copy.heroDetail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            HStack(spacing: 10) {
                HeroMetric(title: copy.heroMetricDefaultTitle, value: copy.heroMetricDefaultValue)
                HeroMetric(title: copy.heroMetricBridgeTitle, value: copy.heroMetricBridgeValue)
                HeroMetric(title: copy.heroMetricScopeTitle, value: copy.heroMetricScopeValue)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [PreparedShowcasePalette.heroStart, PreparedShowcasePalette.heroEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct HeroMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PreparedCapabilitySummarySection: View {
    let copy: PreparedShowcaseCopy

    private var rows: [CapabilityRow] {
        [
            CapabilityRow(title: copy.capabilityWidthTitle, detail: copy.capabilityWidthDetail),
            CapabilityRow(title: copy.capabilityRendererTitle, detail: copy.capabilityRendererDetail),
            CapabilityRow(title: copy.capabilityWhitespaceTitle, detail: copy.capabilityWhitespaceDetail),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                eyebrow: copy.capabilityEyebrow,
                title: copy.capabilityTitle,
                detail: copy.capabilityDetail
            )

            ForEach(rows) { row in
                HStack(alignment: .top, spacing: 14) {
                    Circle()
                        .fill(PreparedShowcasePalette.tint(
                            light: UIColor(red: 0.24, green: 0.45, blue: 0.84, alpha: 0.16),
                            dark: UIColor(red: 0.24, green: 0.45, blue: 0.84, alpha: 0.26)
                        ))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(
                                    PreparedShowcasePalette.tint(
                                        light: UIColor(red: 0.24, green: 0.45, blue: 0.84, alpha: 1.0)
                                    )
                                )
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(.subheadline.weight(.semibold))
                        Text(row.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PreparedShowcasePalette.panelBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PreparedShowcasePalette.softStroke, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }
}

private struct CapabilityRow: Identifiable {
    let title: String
    let detail: String

    var id: String { title }
}

private struct SectionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.bold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DemoSample: Identifiable {
    let id: String
    let title: String
    let eyebrow: String
    let text: NSAttributedString
    let whiteSpaceMode: WhiteSpaceMode
    let sourceID: PreparedTextSourceID
    let accentColor: Color
    let cardColor: Color
    let detail: String
    let capabilityTags: [String]
    let chromeStyle: ChromeStyle
    let numberOfLines: Int
    let lineBreakMode: NSLineBreakMode
    let textAlignment: NSTextAlignment?
    let layoutBehavior: PreparedTextLayoutBehavior
    let preferredWidth: DemoWidthPreset

    enum ChromeStyle {
        case bubble
        case feed
        case list
        case callout
    }

    static func make(language: PreparedTextDemoLanguage) -> [DemoSample] {
        let bodyFont = UIFont.systemFont(ofSize: 17)
        let boldFont = UIFont.boldSystemFont(ofSize: 18)
        let copy = PreparedShowcaseCopy(language: language)

        let bubble = NSMutableAttributedString(
            string: copy.chatBubbleBody,
            attributes: [.font: bodyFont, .foregroundColor: UIColor.label]
        )

        let feed = NSMutableAttributedString(
            string: "\(copy.feedHeadline)\n",
            attributes: [.font: boldFont, .foregroundColor: UIColor.label]
        )
        feed.append(
            NSAttributedString(
                string: copy.feedBody,
                attributes: [.font: bodyFont, .foregroundColor: UIColor.label]
            )
        )

        let list = NSMutableAttributedString(
            string: copy.listHeadline,
            attributes: [.font: boldFont, .foregroundColor: UIColor.label]
        )
        list.append(
            NSAttributedString(
                string: "\n\(copy.listBody)",
                attributes: [.font: bodyFont, .foregroundColor: UIColor.label]
            )
        )

        let callout = NSMutableAttributedString(
            string: copy.calloutBody,
            attributes: [.font: bodyFont, .foregroundColor: UIColor.label]
        )

        return [
            DemoSample(
                id: "chat-bubble",
                title: copy.chatBubbleTitle,
                eyebrow: copy.chatBubbleEyebrow,
                text: bubble,
                whiteSpaceMode: .uikitLiteral,
                sourceID: PreparedTextSourceID("swiftui-pattern-chat-bubble"),
                accentColor: PreparedShowcasePalette.tint(light: UIColor(red: 0.17, green: 0.42, blue: 0.80, alpha: 1.0)),
                cardColor: PreparedShowcasePalette.surface(
                    light: UIColor(red: 0.88, green: 0.94, blue: 1.0, alpha: 1.0),
                    dark: UIColor(red: 0.14, green: 0.21, blue: 0.29, alpha: 1.0)
                ),
                detail: copy.chatBubbleDetail,
                capabilityTags: copy.chatBubbleTags,
                chromeStyle: .bubble,
                numberOfLines: 0,
                lineBreakMode: .byWordWrapping,
                textAlignment: .natural,
                layoutBehavior: .fillProposal,
                preferredWidth: .narrow
            ),
            DemoSample(
                id: "feed-card",
                title: copy.feedCardTitle,
                eyebrow: copy.feedCardEyebrow,
                text: feed,
                whiteSpaceMode: .uikitLiteral,
                sourceID: PreparedTextSourceID("swiftui-pattern-feed-card"),
                accentColor: PreparedShowcasePalette.tint(light: UIColor(red: 0.29, green: 0.47, blue: 0.19, alpha: 1.0)),
                cardColor: PreparedShowcasePalette.surface(
                    light: UIColor(red: 0.95, green: 0.97, blue: 0.90, alpha: 1.0),
                    dark: UIColor(red: 0.15, green: 0.21, blue: 0.15, alpha: 1.0)
                ),
                detail: copy.feedCardDetail,
                capabilityTags: copy.feedCardTags,
                chromeStyle: .feed,
                numberOfLines: 3,
                lineBreakMode: .byTruncatingTail,
                textAlignment: .natural,
                layoutBehavior: .fillProposal,
                preferredWidth: .roomy
            ),
            DemoSample(
                id: "list-row",
                title: copy.listRowTitle,
                eyebrow: copy.listRowEyebrow,
                text: list,
                whiteSpaceMode: .uikitLiteral,
                sourceID: PreparedTextSourceID("swiftui-pattern-list-row"),
                accentColor: PreparedShowcasePalette.tint(light: UIColor(red: 0.46, green: 0.34, blue: 0.78, alpha: 1.0)),
                cardColor: PreparedShowcasePalette.surface(
                    light: UIColor(red: 0.95, green: 0.94, blue: 0.99, alpha: 1.0),
                    dark: UIColor(red: 0.18, green: 0.15, blue: 0.25, alpha: 1.0)
                ),
                detail: copy.listRowDetail,
                capabilityTags: copy.listRowTags,
                chromeStyle: .list,
                numberOfLines: 2,
                lineBreakMode: .byTruncatingTail,
                textAlignment: .natural,
                layoutBehavior: .fillProposal,
                preferredWidth: .balanced
            ),
            DemoSample(
                id: "centered-callout",
                title: copy.calloutTitle,
                eyebrow: copy.calloutEyebrow,
                text: callout,
                whiteSpaceMode: .uikitLiteral,
                sourceID: PreparedTextSourceID("swiftui-pattern-centered-callout"),
                accentColor: PreparedShowcasePalette.tint(light: UIColor(red: 0.74, green: 0.38, blue: 0.14, alpha: 1.0)),
                cardColor: PreparedShowcasePalette.surface(
                    light: UIColor(red: 0.99, green: 0.94, blue: 0.89, alpha: 1.0),
                    dark: UIColor(red: 0.27, green: 0.19, blue: 0.14, alpha: 1.0)
                ),
                detail: copy.calloutDetail,
                capabilityTags: copy.calloutTags,
                chromeStyle: .callout,
                numberOfLines: 2,
                lineBreakMode: .byTruncatingMiddle,
                textAlignment: .center,
                layoutBehavior: .fillProposal,
                preferredWidth: .balanced
            ),
        ]
    }
}

private struct ShowcaseCard: View {
    let sample: DemoSample
    let language: PreparedTextDemoLanguage
    let copy: PreparedShowcaseCopy

    @State private var widthPreset: DemoWidthPreset
    @State private var alignment: DemoAlignmentChoice
    @State private var lineChoice: DemoLineChoice
    @State private var breakChoice: DemoBreakChoice

    init(sample: DemoSample, language: PreparedTextDemoLanguage, copy: PreparedShowcaseCopy) {
        self.sample = sample
        self.language = language
        self.copy = copy
        _widthPreset = State(initialValue: sample.preferredWidth)
        _alignment = State(initialValue: DemoAlignmentChoice(textAlignment: sample.textAlignment ?? .natural))
        _lineChoice = State(initialValue: DemoLineChoice(numberOfLines: sample.numberOfLines))
        _breakChoice = State(initialValue: DemoBreakChoice(mode: sample.lineBreakMode))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sample.eyebrow.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(sample.accentColor)
                    Text(sample.title)
                        .font(.headline)
                }

                Spacer(minLength: 12)

                CapabilityChip(text: "Stage 1", tint: sample.accentColor)
            }

            CapabilityChipRow(tags: sample.capabilityTags, tint: sample.accentColor)
            ShowcaseControlSection(
                tint: sample.accentColor,
                language: language,
                copy: copy,
                widthPreset: $widthPreset,
                alignment: $alignment,
                lineChoice: $lineChoice,
                breakChoice: $breakChoice
            )
            content

            Text(sample.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(PreparedShowcasePalette.panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(PreparedShowcasePalette.softStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .animation(.easeInOut(duration: 0.26), value: widthPreset)
        .animation(.easeInOut(duration: 0.26), value: alignment)
        .animation(.easeInOut(duration: 0.26), value: lineChoice)
        .animation(.easeInOut(duration: 0.26), value: breakChoice)
    }

    @ViewBuilder
    private var content: some View {
        switch sample.chromeStyle {
        case .bubble:
            HStack {
                Spacer(minLength: 24)
                preparedTextPreview()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(sample.cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Text(widthPreset.shortLabel(language: language))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PreparedShowcasePalette.floatingBadgeBackground)
                            .clipShape(Capsule())
                            .offset(x: 12, y: -12)
                    }
            }

        case .feed:
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                sample.accentColor.opacity(0.92),
                                sample.accentColor.opacity(0.55),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 148)
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(copy.feedChromeTitle)
                                .font(.caption.weight(.bold))
                            Text(copy.feedChromeSubtitle)
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                    }

                preparedTextPreview()

                HStack {
                    Label(copy.feedCommentsLabel, systemImage: "message")
                    Spacer()
                    Label(alignment.label(language: language), systemImage: "text.alignleft")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(sample.cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

        case .list:
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(sample.accentColor.opacity(0.14))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .foregroundStyle(sample.accentColor)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.listChromeTitle)
                        .font(.subheadline.weight(.semibold))
                    preparedTextPreview()
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(sample.cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

        case .callout:
            VStack(alignment: .leading, spacing: 10) {
                Text(copy.calloutChromeTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                preparedTextPreview()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sample.cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func preparedTextPreview() -> some View {
        PreparedTextView(
            attributedText: sample.text,
            sourceID: sample.sourceID,
            whiteSpaceMode: sample.whiteSpaceMode,
            numberOfLines: lineChoice.numberOfLines,
            lineBreakMode: breakChoice.mode,
            textAlignment: alignment.textAlignment,
            layoutBehavior: .fillProposal
        )
        .frame(width: widthPreset.width, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShowcaseControlSection: View {
    let tint: Color
    let language: PreparedTextDemoLanguage
    let copy: PreparedShowcaseCopy
    @Binding var widthPreset: DemoWidthPreset
    @Binding var alignment: DemoAlignmentChoice
    @Binding var lineChoice: DemoLineChoice
    @Binding var breakChoice: DemoBreakChoice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PreparedControlGroup(title: copy.widthControlTitle) {
                ForEach(DemoWidthPreset.allCases) { preset in
                    PreparedOptionButton(
                        title: preset.label(language: language),
                        isSelected: widthPreset == preset,
                        tint: tint
                    ) {
                        widthPreset = preset
                    }
                }
            }

            PreparedControlGroup(title: copy.alignmentControlTitle) {
                ForEach(DemoAlignmentChoice.allCases) { choice in
                    PreparedOptionButton(
                        title: choice.label(language: language),
                        isSelected: alignment == choice,
                        tint: tint
                    ) {
                        alignment = choice
                    }
                }
            }

            PreparedControlGroup(title: copy.clampControlTitle) {
                ForEach(DemoLineChoice.allCases) { choice in
                    PreparedOptionButton(
                        title: choice.label(language: language),
                        isSelected: lineChoice == choice,
                        tint: tint
                    ) {
                        lineChoice = choice
                    }
                }
            }

            PreparedControlGroup(title: copy.breakControlTitle) {
                ForEach(DemoBreakChoice.allCases) { choice in
                    PreparedOptionButton(
                        title: choice.label(language: language),
                        isSelected: breakChoice == choice,
                        tint: tint
                    ) {
                        breakChoice = choice
                    }
                }
            }
        }
    }
}

private struct PreparedInteractiveLinkSection: View {
    let copy: PreparedShowcaseCopy
    let language: PreparedTextDemoLanguage

    @State private var lastTapped = ""
    @State private var alignment: DemoAlignmentChoice = .center
    @State private var lineChoice: DemoLineChoice = .three
    @State private var breakChoice: DemoBreakChoice = .tail
    @State private var widthPreset: DemoWidthPreset = .balanced

    private let tint = PreparedShowcasePalette.tint(light: UIColor(red: 0.12, green: 0.50, blue: 0.46, alpha: 1.0))

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                eyebrow: copy.linkEyebrow,
                title: copy.linkTitle,
                detail: copy.linkDetail
            )

            VStack(alignment: .leading, spacing: 14) {
                CapabilityChipRow(
                    tags: copy.linkTags,
                    tint: tint
                )

                PreparedControlGroup(title: copy.alignmentControlTitle) {
                    ForEach(DemoAlignmentChoice.allCases) { choice in
                        PreparedOptionButton(
                            title: choice.label(language: language),
                            isSelected: alignment == choice,
                            tint: tint
                        ) {
                            alignment = choice
                        }
                    }
                }

                PreparedControlGroup(title: copy.clampControlTitle) {
                    ForEach(DemoLineChoice.allCases) { choice in
                        PreparedOptionButton(
                            title: choice.label(language: language),
                            isSelected: lineChoice == choice,
                            tint: tint
                        ) {
                            lineChoice = choice
                        }
                    }
                }

                PreparedControlGroup(title: copy.breakControlTitle) {
                    ForEach(DemoBreakChoice.allCases) { choice in
                        PreparedOptionButton(
                            title: choice.label(language: language),
                            isSelected: breakChoice == choice,
                            tint: tint
                        ) {
                            breakChoice = choice
                        }
                    }
                }

                PreparedControlGroup(title: copy.widthControlTitle) {
                    ForEach(DemoWidthPreset.allCases) { preset in
                        PreparedOptionButton(
                            title: preset.label(language: language),
                            isSelected: widthPreset == preset,
                            tint: tint
                        ) {
                            widthPreset = preset
                        }
                    }
                }

                PreparedTextView(
                    attributedText: copy.localizedLinkedText,
                    sourceID: PreparedTextSourceID("swiftui-pattern-link-card"),
                    whiteSpaceMode: .uikitLiteral,
                    numberOfLines: lineChoice.numberOfLines,
                    lineBreakMode: breakChoice.mode,
                    textAlignment: alignment.textAlignment,
                    automaticallyOpensLinks: false,
                    linkTapHandler: { url in
                        lastTapped = "\(copy.linkTappedPrefix) \(url.lastPathComponent)"
                    },
                    layoutBehavior: .fillProposal
                )
                .frame(width: widthPreset.width, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(PreparedShowcasePalette.insetBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text(lastTapped)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PreparedShowcasePalette.panelBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PreparedShowcasePalette.softStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .onAppear {
            if lastTapped.isEmpty {
                lastTapped = copy.linkIdleStatus
            }
        }
        .onChange(of: language) { _ in
            lastTapped = copy.linkIdleStatus
        }
        .animation(.easeInOut(duration: 0.26), value: alignment)
        .animation(.easeInOut(duration: 0.26), value: lineChoice)
        .animation(.easeInOut(duration: 0.26), value: breakChoice)
        .animation(.easeInOut(duration: 0.26), value: widthPreset)
    }
}

private struct WhiteSpaceContractSample: Identifiable {
    let id: String
    let title: String
    let mode: WhiteSpaceMode
    let detail: String
    let tint: Color
    let text: NSAttributedString

    static func make(language: PreparedTextDemoLanguage) -> [WhiteSpaceContractSample] {
        let copy = PreparedShowcaseCopy(language: language)
        let font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        let shared = NSAttributedString(
            string: copy.whitespaceBody,
            attributes: [.font: font, .foregroundColor: UIColor.label]
        )

        return [
            WhiteSpaceContractSample(
                id: "uikit-literal",
                title: copy.whitespaceLiteralTitle,
                mode: .uikitLiteral,
                detail: copy.whitespaceLiteralDetail,
                tint: PreparedShowcasePalette.tint(light: UIColor(red: 0.15, green: 0.44, blue: 0.74, alpha: 1.0)),
                text: shared
            ),
            WhiteSpaceContractSample(
                id: "css-normal",
                title: copy.whitespaceCSSTitle,
                mode: .cssNormal,
                detail: copy.whitespaceCSSDetail,
                tint: PreparedShowcasePalette.tint(light: UIColor(red: 0.62, green: 0.42, blue: 0.14, alpha: 1.0)),
                text: shared
            ),
            WhiteSpaceContractSample(
                id: "pre-wrap",
                title: copy.whitespacePreWrapTitle,
                mode: .preWrap,
                detail: copy.whitespacePreWrapDetail,
                tint: PreparedShowcasePalette.tint(light: UIColor(red: 0.24, green: 0.52, blue: 0.28, alpha: 1.0)),
                text: shared
            ),
        ]
    }
}

private struct PreparedWhitespaceContractSection: View {
    let samples: [WhiteSpaceContractSample]
    let copy: PreparedShowcaseCopy
    let language: PreparedTextDemoLanguage

    @State private var selectedMode: WhiteSpaceMode = .uikitLiteral
    @State private var widthPreset: DemoWidthPreset = .balanced
    @State private var alignment: DemoAlignmentChoice = .leading

    private var selectedSample: WhiteSpaceContractSample {
        samples.first(where: { $0.mode == selectedMode }) ?? samples[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                eyebrow: copy.whitespaceEyebrow,
                title: copy.whitespaceTitle,
                detail: copy.whitespaceDetail
            )

            VStack(alignment: .leading, spacing: 14) {
                PreparedControlGroup(title: copy.modeControlTitle) {
                    ForEach(samples) { sample in
                        PreparedOptionButton(
                            title: sample.title,
                            isSelected: selectedMode == sample.mode,
                            tint: sample.tint
                        ) {
                            selectedMode = sample.mode
                        }
                    }
                }

                PreparedControlGroup(title: copy.widthControlTitle) {
                    ForEach(DemoWidthPreset.allCases) { preset in
                        PreparedOptionButton(
                            title: preset.label(language: language),
                            isSelected: widthPreset == preset,
                            tint: selectedSample.tint
                        ) {
                            widthPreset = preset
                        }
                    }
                }

                PreparedControlGroup(title: copy.alignmentControlTitle) {
                    ForEach(DemoAlignmentChoice.allCases) { choice in
                        PreparedOptionButton(
                            title: choice.label(language: language),
                            isSelected: alignment == choice,
                            tint: selectedSample.tint
                        ) {
                            alignment = choice
                        }
                    }
                }

                PreparedTextView(
                    attributedText: selectedSample.text,
                    sourceID: PreparedTextSourceID("whitespace-contract-\(selectedSample.id)"),
                    whiteSpaceMode: selectedSample.mode,
                    lineBreakMode: .byWordWrapping,
                    textAlignment: alignment.textAlignment,
                    layoutBehavior: .fillProposal
                )
                .frame(width: widthPreset.width, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(selectedSample.tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(selectedSample.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(PreparedShowcasePalette.panelBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PreparedShowcasePalette.softStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .animation(.easeInOut(duration: 0.26), value: selectedMode)
        .animation(.easeInOut(duration: 0.26), value: widthPreset)
        .animation(.easeInOut(duration: 0.26), value: alignment)
    }
}

private struct PreparedWidthLabSection: View {
    let attributedText: NSAttributedString
    let sourceID: PreparedTextSourceID
    let whiteSpaceMode: WhiteSpaceMode
    let tint: Color
    let copy: PreparedShowcaseCopy
    let language: PreparedTextDemoLanguage

    @State private var width: Double = 220
    @State private var alignment: DemoAlignmentChoice = .leading

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                eyebrow: copy.widthLabEyebrow,
                title: copy.widthLabTitle,
                detail: copy.widthLabDetail
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CapabilityChip(text: copy.preparedReuseChipLabel, tint: tint)
                    Spacer()
                    Text("\(Int(width))pt")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $width, in: 96...320, step: 8)
                    .tint(tint)

                PreparedControlGroup(title: copy.widthControlTitle) {
                    ForEach(DemoWidthPreset.allCases) { preset in
                        PreparedOptionButton(
                            title: preset.label(language: language),
                            isSelected: Int(width.rounded()) == Int(preset.width),
                            tint: tint
                        ) {
                            width = preset.width
                        }
                    }
                }

                PreparedControlGroup(title: copy.alignmentControlTitle) {
                    ForEach(DemoAlignmentChoice.allCases) { choice in
                        PreparedOptionButton(
                            title: choice.label(language: language),
                            isSelected: alignment == choice,
                            tint: tint
                        ) {
                            alignment = choice
                        }
                    }
                }

                PreparedTextView(
                    attributedText: attributedText,
                    sourceID: sourceID,
                    whiteSpaceMode: whiteSpaceMode,
                    numberOfLines: 0,
                    lineBreakMode: .byWordWrapping,
                    textAlignment: alignment.textAlignment,
                    layoutBehavior: .fillProposal
                )
                .frame(width: CGFloat(width), alignment: .leading)
                .padding(14)
                .background(PreparedShowcasePalette.insetBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(18)
            .background(PreparedShowcasePalette.panelBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PreparedShowcasePalette.softStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .onAppear {
            width = 220
        }
        .animation(.easeInOut(duration: 0.26), value: width)
        .animation(.easeInOut(duration: 0.26), value: alignment)
    }
}

private struct PreparedShrinkwrapShowdownSection: View {
    let copy: PreparedShowcaseCopy
    private let attributedText: NSAttributedString
    private let preparedText: PreparedText

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var containerWidth: Double = 340

    private let tint = PreparedShowcasePalette.tint(
        light: UIColor(red: 0.18, green: 0.38, blue: 0.79, alpha: 1.0),
        dark: UIColor(red: 0.42, green: 0.62, blue: 0.98, alpha: 1.0)
    )

    init(copy: PreparedShowcaseCopy, language: PreparedTextDemoLanguage) {
        self.copy = copy

        let attributedText = Self.makeAttributedText(copy: copy)
        self.attributedText = attributedText
        self.preparedText = PreparedTextSystem.shared.prepare(
            attributedText,
            sourceID: PreparedTextSourceID("swiftui-pattern-shrinkwrap-showdown-payload"),
            options: PreparedTextOptions(
                whiteSpaceMode: .uikitLiteral,
                locale: Locale(identifier: language.localeIdentifier)
            )
        )
    }

    var body: some View {
        let showdown = metrics(for: CGFloat(containerWidth))

        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                eyebrow: copy.shrinkwrapEyebrow,
                title: copy.shrinkwrapTitle,
                detail: copy.shrinkwrapDetail
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CapabilityChip(text: "\(Int(containerWidth))pt", tint: tint)
                    Spacer()
                    Text("\(copy.shrinkwrapLinesLabel): \(showdown.lineCount)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $containerWidth, in: 240...420, step: 4)
                    .tint(tint)

                showdownCards(showdown: showdown)

                Text(copy.shrinkwrapFootnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(PreparedShowcasePalette.panelBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PreparedShowcasePalette.softStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .animation(.easeInOut(duration: 0.26), value: containerWidth)
    }

    @ViewBuilder
    private func showdownCards(showdown: PreparedShrinkwrapMetrics) -> some View {
        let fitsCompactLayout = horizontalSizeClass == .compact
        let compactWidthLimit = max(188, UIScreen.main.bounds.width - 116)
        let cssWidth = fitsCompactLayout ? min(showdown.cssWidth, compactWidthLimit) : showdown.cssWidth
        let tightWidth = fitsCompactLayout ? min(showdown.tightWidth, compactWidthLimit) : showdown.tightWidth

        if fitsCompactLayout {
            VStack(alignment: .leading, spacing: 14) {
                showdownCard(
                    title: copy.shrinkwrapFitContentTitle,
                    detail: copy.shrinkwrapFitContentDetail,
                    width: cssWidth,
                    badge: "\(Int(showdown.cssWidth))pt",
                    tint: tint.opacity(0.86)
                )

                showdownCard(
                    title: copy.shrinkwrapPretextTitle,
                    detail: copy.shrinkwrapPretextDetail,
                    width: tightWidth,
                    badge: "\(Int(showdown.tightWidth))pt",
                    tint: tint
                )
            }
        } else {
            HStack(alignment: .top, spacing: 14) {
                showdownCard(
                    title: copy.shrinkwrapFitContentTitle,
                    detail: copy.shrinkwrapFitContentDetail,
                    width: cssWidth,
                    badge: "\(Int(showdown.cssWidth))pt",
                    tint: tint.opacity(0.86)
                )

                showdownCard(
                    title: copy.shrinkwrapPretextTitle,
                    detail: copy.shrinkwrapPretextDetail,
                    width: tightWidth,
                    badge: "\(Int(showdown.tightWidth))pt",
                    tint: tint
                )
            }
        }
    }

    private func showdownCard(
        title: String,
        detail: String,
        width: CGFloat,
        badge: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                CapabilityChip(text: badge, tint: tint)
            }

            PreparedTextView(
                preparedText: preparedText,
                lineBreakMode: .byWordWrapping,
                layoutBehavior: .fillProposal
            )
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(PreparedShowcasePalette.insetBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private static func makeAttributedText(copy: PreparedShowcaseCopy) -> NSAttributedString {
        NSMutableAttributedString(
            string: copy.shrinkwrapBody,
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.label,
            ]
        )
    }

    private func metrics(for maxWidth: CGFloat) -> PreparedShrinkwrapMetrics {
        let system = PreparedTextSystem.shared
        let lineHeight = preparedText.defaultLineHeight
        let layout = system.layout(preparedText, maxWidth: maxWidth, lineHeight: lineHeight)
        let cssWidth = min(maxWidth, max(layout.maxPaintWidth, 1))
        let targetLineCount = max(layout.lineCount, 1)

        var low: CGFloat = 80
        var high: CGFloat = maxWidth
        var best = cssWidth

        for _ in 0..<14 {
            let mid = ((low + high) / 2).rounded(.toNearestOrEven)
            let candidate = system.layout(preparedText, maxWidth: mid, lineHeight: lineHeight)
            if candidate.lineCount == targetLineCount {
                best = mid
                high = mid
            } else {
                low = mid + 1
            }
        }

        return PreparedShrinkwrapMetrics(
            lineCount: targetLineCount,
            cssWidth: ceil(cssWidth),
            tightWidth: ceil(min(maxWidth, best))
        )
    }
}

private struct PreparedShrinkwrapMetrics {
    let lineCount: Int
    let cssWidth: CGFloat
    let tightWidth: CGFloat
}

private struct PreparedPlayLabSection: View {
    let copy: PreparedShowcaseCopy
    let language: PreparedTextDemoLanguage
    private let preparedText: PreparedText

    @State private var scene: PreparedPlayLabScene = .wave
    @State private var speed: Double = 1.0

    private let tint = PreparedShowcasePalette.tint(
        light: UIColor(red: 0.64, green: 0.22, blue: 0.18, alpha: 1.0),
        dark: UIColor(red: 0.89, green: 0.47, blue: 0.40, alpha: 1.0)
    )

    init(copy: PreparedShowcaseCopy, language: PreparedTextDemoLanguage) {
        self.copy = copy
        self.language = language
        let attributedText = Self.makeAttributedText(copy: copy)
        self.preparedText = PreparedTextSystem.shared.prepare(
            attributedText,
            sourceID: PreparedTextSourceID("swiftui-pattern-play-lab"),
            options: PreparedTextOptions(
                whiteSpaceMode: .uikitLiteral,
                locale: Locale(identifier: language.localeIdentifier)
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                eyebrow: copy.playLabEyebrow,
                title: copy.playLabTitle,
                detail: copy.playLabDetail
            )

            VStack(alignment: .leading, spacing: 14) {
                PreparedControlGroup(title: copy.modeControlTitle) {
                    ForEach(PreparedPlayLabScene.allCases) { option in
                        PreparedOptionButton(
                            title: option.label(language: language),
                            isSelected: scene == option,
                            tint: tint
                        ) {
                            scene = option
                        }
                    }
                }

                HStack(spacing: 12) {
                    Text(copy.motionControlTitle.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Slider(value: $speed, in: 0.4...2.2, step: 0.1)
                        .tint(tint)

                    Text(String(format: "%.1fx", speed))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                    let time = context.date.timeIntervalSinceReferenceDate * speed

                    VStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { laneIndex in
                            let lane = laneState(for: laneIndex, time: time)
                            PreparedPlayLabLane(
                                lane: lane,
                                preparedText: preparedText,
                                language: language,
                                tint: tint
                            )
                        }
                    }
                }

                Text(copy.playLabFootnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(PreparedShowcasePalette.panelBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PreparedShowcasePalette.softStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .animation(.easeInOut(duration: 0.26), value: scene)
        .animation(.easeInOut(duration: 0.26), value: speed)
    }

    private static func makeAttributedText(copy: PreparedShowcaseCopy) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: copy.playLabLead,
            attributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.label,
            ]
        )
        text.append(
            NSAttributedString(
                string: copy.playLabBody,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                    .foregroundColor: UIColor.label,
                ]
            )
        )
        return text
    }

    private func laneState(for index: Int, time: TimeInterval) -> PreparedPlayLabLaneState {
        let phase = time + Double(index) * 0.7
        let width: CGFloat
        let alignment: DemoAlignmentChoice
        let lines: DemoLineChoice
        let breakChoice: DemoBreakChoice

        switch scene {
        case .pulse:
            let oscillation = sin(phase * 1.8)
            width = CGFloat(max(144, min(310, 214 + oscillation * 76)))
            alignment = [.leading, .center, .trailing][Int(floor(phase * 0.6)).quotientAndRemainder(dividingBy: 3).remainder]
            lines = index == 1 ? .three : .full
            breakChoice = .wrap

        case .wave:
            let oscillation = sin(phase * 1.4)
            width = CGFloat(max(148, min(318, 226 + oscillation * 88)))
            alignment = [DemoAlignmentChoice.leading, .center, .trailing][index]
            lines = .full
            breakChoice = .wrap

        case .mixer:
            let oscillation = sin(phase * (1.2 + Double(index) * 0.45))
            width = CGFloat(max(136, min(304, 196 + oscillation * 94)))
            alignment = oscillation > 0.28 ? .trailing : (oscillation < -0.28 ? .leading : .center)
            lines = [DemoLineChoice.two, .three, .full][index]
            breakChoice = [DemoBreakChoice.tail, .middle, .wrap][index]
        }

        return PreparedPlayLabLaneState(
            id: index,
            width: width,
            alignment: alignment,
            lineChoice: lines,
            breakChoice: breakChoice
        )
    }
}

private struct PreparedPlayLabLane: View {
    let lane: PreparedPlayLabLaneState
    let preparedText: PreparedText
    let language: PreparedTextDemoLanguage
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                CapabilityChip(
                    text: "\(Int(lane.width))pt",
                    tint: tint
                )
                Text(lane.alignment.label(language: language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(lane.breakChoice.label(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            PreparedTextView(
                preparedText: preparedText,
                numberOfLines: lane.lineChoice.numberOfLines,
                lineBreakMode: lane.breakChoice.mode,
                textAlignment: lane.alignment.textAlignment,
                layoutBehavior: .fillProposal
            )
            .frame(width: lane.width, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .background(PreparedShowcasePalette.insetBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct PreparedPlayLabLaneState: Identifiable {
    let id: Int
    let width: CGFloat
    let alignment: DemoAlignmentChoice
    let lineChoice: DemoLineChoice
    let breakChoice: DemoBreakChoice
}

private enum PreparedPlayLabScene: String, CaseIterable, Identifiable {
    case pulse
    case wave
    case mixer

    var id: String { rawValue }

    func label(language: PreparedTextDemoLanguage) -> String {
        switch (language, self) {
        case (.english, .pulse):
            return "Pulse"
        case (.english, .wave):
            return "Wave"
        case (.english, .mixer):
            return "Mixer"
        case (.korean, .pulse):
            return "박동"
        case (.korean, .wave):
            return "파동"
        case (.korean, .mixer):
            return "믹서"
        case (.japanese, .pulse):
            return "脈動"
        case (.japanese, .wave):
            return "波"
        case (.japanese, .mixer):
            return "ミキサー"
        case (.chineseSimplified, .pulse):
            return "脉冲"
        case (.chineseSimplified, .wave):
            return "波形"
        case (.chineseSimplified, .mixer):
            return "混合"
        case (.chineseTraditional, .pulse):
            return "脈衝"
        case (.chineseTraditional, .wave):
            return "波形"
        case (.chineseTraditional, .mixer):
            return "混合"
        }
    }
}

private enum DemoWidthPreset: String, CaseIterable, Identifiable {
    case narrow
    case balanced
    case roomy

    var id: String { rawValue }

    var width: Double {
        switch self {
        case .narrow:
            return 168
        case .balanced:
            return 232
        case .roomy:
            return 312
        }
    }

    func label(language: PreparedTextDemoLanguage) -> String {
        switch self {
        case .narrow:
            switch language {
            case .english: return "Narrow"
            case .korean: return "좁게"
            case .japanese: return "狭め"
            case .chineseSimplified: return "窄"
            case .chineseTraditional: return "窄"
            }
        case .balanced:
            switch language {
            case .english: return "Balanced"
            case .korean: return "보통"
            case .japanese: return "標準"
            case .chineseSimplified: return "均衡"
            case .chineseTraditional: return "均衡"
            }
        case .roomy:
            switch language {
            case .english: return "Roomy"
            case .korean: return "넓게"
            case .japanese: return "広め"
            case .chineseSimplified: return "宽"
            case .chineseTraditional: return "寬"
            }
        }
    }

    func shortLabel(language: PreparedTextDemoLanguage) -> String {
        switch self {
        case .narrow:
            switch language {
            case .english: return "Narrow width"
            case .korean: return "좁은 폭"
            case .japanese: return "狭い幅"
            case .chineseSimplified: return "窄幅"
            case .chineseTraditional: return "窄幅"
            }
        case .balanced:
            switch language {
            case .english: return "Balanced width"
            case .korean: return "보통 폭"
            case .japanese: return "標準幅"
            case .chineseSimplified: return "标准宽度"
            case .chineseTraditional: return "標準寬度"
            }
        case .roomy:
            switch language {
            case .english: return "Roomy width"
            case .korean: return "넓은 폭"
            case .japanese: return "広い幅"
            case .chineseSimplified: return "宽幅"
            case .chineseTraditional: return "寬幅"
            }
        }
    }
}

private enum DemoAlignmentChoice: String, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    init(textAlignment: NSTextAlignment) {
        switch textAlignment {
        case .center:
            self = .center
        case .right:
            self = .trailing
        default:
            self = .leading
        }
    }

    var id: String { rawValue }

    var textAlignment: NSTextAlignment {
        switch self {
        case .leading:
            return .left
        case .center:
            return .center
        case .trailing:
            return .right
        }
    }

    func label(language: PreparedTextDemoLanguage) -> String {
        switch self {
        case .leading:
            switch language {
            case .english: return "Leading"
            case .korean: return "왼쪽"
            case .japanese: return "左"
            case .chineseSimplified: return "左对齐"
            case .chineseTraditional: return "靠左"
            }
        case .center:
            switch language {
            case .english: return "Center"
            case .korean: return "가운데"
            case .japanese: return "中央"
            case .chineseSimplified: return "居中"
            case .chineseTraditional: return "置中"
            }
        case .trailing:
            switch language {
            case .english: return "Trailing"
            case .korean: return "오른쪽"
            case .japanese: return "右"
            case .chineseSimplified: return "右对齐"
            case .chineseTraditional: return "靠右"
            }
        }
    }
}

private enum DemoLineChoice: String, CaseIterable, Identifiable {
    case full
    case two
    case three

    init(numberOfLines: Int) {
        switch numberOfLines {
        case 2:
            self = .two
        case 3:
            self = .three
        default:
            self = .full
        }
    }

    var id: String { rawValue }

    var numberOfLines: Int {
        switch self {
        case .full:
            return 0
        case .two:
            return 2
        case .three:
            return 3
        }
    }

    func label(language: PreparedTextDemoLanguage) -> String {
        switch self {
        case .full:
            switch language {
            case .english: return "Full"
            case .korean: return "전체"
            case .japanese: return "すべて"
            case .chineseSimplified: return "全部"
            case .chineseTraditional: return "全部"
            }
        case .two:
            switch language {
            case .english: return "2 lines"
            case .korean: return "2줄"
            case .japanese: return "2行"
            case .chineseSimplified: return "2行"
            case .chineseTraditional: return "2行"
            }
        case .three:
            switch language {
            case .english: return "3 lines"
            case .korean: return "3줄"
            case .japanese: return "3行"
            case .chineseSimplified: return "3行"
            case .chineseTraditional: return "3行"
            }
        }
    }
}

private enum DemoBreakChoice: String, CaseIterable, Identifiable {
    case wrap
    case tail
    case middle

    init(mode: NSLineBreakMode) {
        switch mode {
        case .byTruncatingMiddle:
            self = .middle
        case .byTruncatingTail:
            self = .tail
        default:
            self = .wrap
        }
    }

    var id: String { rawValue }

    var mode: NSLineBreakMode {
        switch self {
        case .wrap:
            return .byWordWrapping
        case .tail:
            return .byTruncatingTail
        case .middle:
            return .byTruncatingMiddle
        }
    }

    func label(language: PreparedTextDemoLanguage) -> String {
        switch self {
        case .wrap:
            switch language {
            case .english: return "Wrap"
            case .korean: return "줄바꿈"
            case .japanese: return "折返し"
            case .chineseSimplified: return "换行"
            case .chineseTraditional: return "換行"
            }
        case .tail:
            switch language {
            case .english: return "Tail"
            case .korean: return "끝 생략"
            case .japanese: return "末尾"
            case .chineseSimplified: return "尾部"
            case .chineseTraditional: return "尾端"
            }
        case .middle:
            switch language {
            case .english: return "Middle"
            case .korean: return "중간 생략"
            case .japanese: return "中央"
            case .chineseSimplified: return "中间"
            case .chineseTraditional: return "中間"
            }
        }
    }
}

private struct PreparedControlGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content
                }
            }
        }
    }
}

private struct PreparedOptionButton: View {
    let title: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.26)) {
                action()
            }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? tint : tint.opacity(0.12))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(tint.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct PreparedShowcaseCopy {
    let language: PreparedTextDemoLanguage

    var heroTitle: String { value(en: "Prepare once. Reflow often.", ko: "한 번 준비하고, 자주 재배치하세요.", ja: "一度 prepare して、何度も再フロー。", zhHans: "准备一次，反复重排。", zhHant: "準備一次，反覆重排。") }
    var heroDetail: String { value(en: "This tab is now interactive on purpose. Tap width, alignment, line-limit, and truncation controls to test the read-only prepared renderer where teams actually adopt it.", ko: "이 탭은 의도적으로 상호작용형입니다. 너비, 정렬, 줄 수 제한, truncation 컨트롤을 눌러 실제 제품 도입 지점의 read-only prepared renderer를 시험해보세요.", ja: "このタブは意図的にインタラクティブです。幅、整列、行数制限、truncation を切り替えて、実際の導入面で read-only prepared renderer を試せます。", zhHans: "这个标签页刻意做成可交互。点击宽度、对齐、行数限制和截断控件，直接测试团队实际会采用的只读 prepared renderer。", zhHant: "這個分頁刻意做成可互動。點擊寬度、對齊、行數限制與截斷控制，直接測試團隊實際會採用的唯讀 prepared renderer。") }
    var heroMetricDefaultTitle: String { value(en: "Default", ko: "기본", ja: "既定", zhHans: "默认", zhHant: "預設") }
    var heroMetricDefaultValue: String { "UIKit literal" }
    var heroMetricBridgeTitle: String { value(en: "Bridge", ko: "브리지", ja: "ブリッジ", zhHans: "桥接", zhHant: "橋接") }
    var heroMetricBridgeValue: String { "SwiftUI -> UIKit" }
    var heroMetricScopeTitle: String { value(en: "Scope", ko: "범위", ja: "範囲", zhHans: "范围", zhHant: "範圍") }
    var heroMetricScopeValue: String { value(en: "Read-only surfaces", ko: "읽기 전용 서피스", ja: "読み取り専用サーフェス", zhHans: "只读界面", zhHant: "唯讀介面") }

    var realSurfacesEyebrow: String { value(en: "Real surfaces", ko: "실전 서피스", ja: "実運用サーフェス", zhHans: "真实界面", zhHant: "真實介面") }
    var realSurfacesTitle: String { value(en: "Press the controls and watch the same prepared payload reflow", ko: "컨트롤을 눌러 같은 prepared payload가 다시 흐르는 모습을 보세요", ja: "同じ prepared payload が再フローする様子を操作して確認できます", zhHans: "点击控件，观察同一个 prepared payload 如何重新排版", zhHant: "點擊控制，觀察同一個 prepared payload 如何重新排版") }
    var realSurfacesDetail: String { value(en: "Each card now exposes width, alignment, line-limit, and line-break controls so the demo behaves like a testing lab instead of a static marketing panel.", ko: "각 카드는 이제 너비, 정렬, 줄 수 제한, 줄바꿈 컨트롤을 노출해 정적인 소개 화면이 아니라 실제 테스트 실험실처럼 동작합니다.", ja: "各カードは幅、整列、行数制限、改行制御を公開し、静的な紹介画面ではなくテスト用ラボとして動作します。", zhHans: "每张卡片都提供宽度、对齐、行数限制和换行控制，让这个 demo 像测试实验室而不是静态展示页。", zhHant: "每張卡片都提供寬度、對齊、行數限制與換行控制，讓這個 demo 更像測試實驗室，而不是靜態展示頁。") }

    var capabilityEyebrow: String { value(en: "What to test", ko: "테스트 포인트", ja: "確認ポイント", zhHans: "测试重点", zhHant: "測試重點") }
    var capabilityTitle: String { value(en: "Three behaviors this tab should make obvious", ko: "이 탭이 분명하게 보여줘야 할 세 가지 동작", ja: "このタブで明確に見えるべき三つの挙動", zhHans: "这个标签页应该清楚展示的三个行为", zhHant: "這個分頁應清楚展示的三個行為") }
    var capabilityDetail: String { value(en: "The controls below are intentionally shaped like buttons so the demo can act as a hands-on renderer checklist.", ko: "아래 컨트롤은 일부러 버튼처럼 보여서 데모가 직접 눌러보는 renderer 체크리스트 역할을 하도록 만들었습니다.", ja: "下のコントロールは意図的にボタンらしく作られており、このデモが実際に触れる renderer チェックリストになります。", zhHans: "下面的控件刻意设计成按钮形态，让这个 demo 可以直接充当可操作的 renderer 检查表。", zhHant: "下面的控制刻意設計成按鈕樣式，讓這個 demo 可以直接成為可操作的 renderer 檢查表。") }
    var capabilityWidthTitle: String { value(en: "Width churn", ko: "폭 변화", ja: "幅変動", zhHans: "宽度变化", zhHant: "寬度變化") }
    var capabilityWidthDetail: String { value(en: "Prepared payload reuse is easiest to trust when the same copy keeps negotiating new widths without a fresh prepare step.", ko: "같은 텍스트가 prepare를 다시 하지 않고도 계속 다른 폭을 받아들일 때 prepared payload 재사용을 가장 신뢰하기 쉽습니다.", ja: "同じテキストが prepare をやり直さずに新しい幅へ再交渉できると、prepared payload の再利用を最も信頼しやすくなります。", zhHans: "当同一份文本无需重新 prepare 就能持续协商新宽度时，prepared payload 的复用价值最直观。", zhHant: "當同一份文字不需重新 prepare 就能持續協商新寬度時，prepared payload 的重用價值最直觀。") }
    var capabilityRendererTitle: String { value(en: "Renderer controls", ko: "렌더러 컨트롤", ja: "レンダラー制御", zhHans: "渲染器控制", zhHant: "渲染器控制") }
    var capabilityRendererDetail: String { value(en: "Line limit, truncation, alignment, and interactive links should all be testable without leaving the demo.", ko: "줄 수 제한, truncation, 정렬, 링크 상호작용을 데모 안에서 바로 테스트할 수 있어야 합니다.", ja: "行数制限、truncation、整列、リンク操作をこのデモ内でそのまま確認できるべきです。", zhHans: "行数限制、截断、对齐和链接交互都应该能在这个 demo 内直接测试。", zhHant: "行數限制、截斷、對齊與連結互動都應該能在這個 demo 內直接測試。") }
    var capabilityWhitespaceTitle: String { value(en: "Whitespace contract", ko: "공백 계약", ja: "空白契約", zhHans: "空白约定", zhHant: "空白契約") }
    var capabilityWhitespaceDetail: String { value(en: "UIKit literal is still the default contract. CSS-like collapse and pre-wrap stay explicit opt-in modes.", ko: "기본 계약은 여전히 UIKit literal입니다. CSS-like collapse와 pre-wrap은 명시적으로 opt-in하는 모드입니다.", ja: "既定の契約は UIKit literal です。CSS 風 collapse と pre-wrap は明示的な opt-in モードのままです。", zhHans: "默认契约仍然是 UIKit literal。CSS 式折叠和 pre-wrap 仍然是明确的可选模式。", zhHant: "預設契約仍然是 UIKit literal。CSS 式折疊與 pre-wrap 仍然是明確的可選模式。") }

    var widthControlTitle: String { value(en: "Width", ko: "너비", ja: "幅", zhHans: "宽度", zhHant: "寬度") }
    var alignmentControlTitle: String { value(en: "Alignment", ko: "정렬", ja: "整列", zhHans: "对齐", zhHant: "對齊") }
    var clampControlTitle: String { value(en: "Clamp", ko: "줄 수", ja: "行数", zhHans: "行数", zhHant: "行數") }
    var breakControlTitle: String { value(en: "Break", ko: "줄바꿈", ja: "改行", zhHans: "换行", zhHant: "換行") }
    var modeControlTitle: String { value(en: "Mode", ko: "모드", ja: "モード", zhHans: "模式", zhHant: "模式") }

    var chatBubbleTitle: String { value(en: "Chat Bubble", ko: "채팅 버블", ja: "チャットバブル", zhHans: "聊天气泡", zhHant: "聊天氣泡") }
    var chatBubbleEyebrow: String { value(en: "Fast width churn", ko: "빠른 폭 변화", ja: "高速な幅変動", zhHans: "快速宽度变化", zhHant: "快速寬度變化") }
    var chatBubbleBody: String { value(en: "Mina: I switched this thread to the prepared renderer. Heights stayed stable while the bubble width kept changing during quick replies.", ko: "미나: 이 스레드를 prepared renderer로 바꿨어요. 빠른 답장 중에 버블 너비가 계속 바뀌어도 높이는 안정적으로 유지됐어요.", ja: "ミナ: このスレッドを prepared renderer に切り替えました。クイック返信でバブル幅が変わっても高さは安定していました。", zhHans: "Mina：我把这个线程切到了 prepared renderer。即使快速回复时气泡宽度不断变化，高度也保持稳定。", zhHant: "Mina：我把這個討論串切到 prepared renderer。即使快速回覆時氣泡寬度不斷變化，高度也保持穩定。") }
    var chatBubbleDetail: String { value(en: "A conversation bubble is the simplest place to notice stable height prediction when proposal width changes repeatedly.", ko: "대화 버블은 제안 너비가 반복해서 바뀔 때 높이 예측 안정성을 가장 쉽게 체감할 수 있는 지점입니다.", ja: "会話バブルは、提案幅が繰り返し変わるときの高さ予測の安定性を最も感じやすい場所です。", zhHans: "对话气泡是最容易观察宽度反复变化时高度预测是否稳定的场景。", zhHant: "對話氣泡是最容易觀察寬度反覆變化時高度預測是否穩定的場景。") }
    var chatBubbleTags: [String] { [value(en: "UIKit literal", ko: "UIKit literal", ja: "UIKit literal", zhHans: "UIKit literal", zhHant: "UIKit literal"), value(en: "Read-only bubble", ko: "읽기 전용 버블", ja: "読み取り専用バブル", zhHans: "只读气泡", zhHant: "唯讀氣泡"), value(en: "Prepared sizing", ko: "Prepared sizing", ja: "Prepared sizing", zhHans: "Prepared sizing", zhHant: "Prepared sizing")] }

    var feedCardTitle: String { value(en: "Feed Summary Card", ko: "피드 요약 카드", ja: "フィード要約カード", zhHans: "信息流摘要卡片", zhHant: "動態摘要卡片") }
    var feedCardEyebrow: String { value(en: "Dense read-only card", ko: "밀도 높은 읽기 전용 카드", ja: "密度の高い読み取り専用カード", zhHans: "高密度只读卡片", zhHant: "高密度唯讀卡片") }
    var feedHeadline: String { value(en: "Prepared release checklist", ko: "Prepared 릴리즈 체크리스트", ja: "Prepared リリースチェックリスト", zhHans: "Prepared 发布检查清单", zhHant: "Prepared 發佈檢查清單") }
    var feedBody: String { value(en: "Move strict correctness into simulator gating, keep host CoreText as report-only, and make stage rollout stories obvious in the product UI.", ko: "엄격한 정확도 검증은 simulator gate로 옮기고, host CoreText는 report-only로 두며, 제품 UI에서 stage 도입 흐름이 분명히 보이게 해야 합니다.", ja: "厳格な正確性検証は simulator gate に移し、host CoreText は report-only のままにし、製品 UI で stage rollout が明確に見えるようにします。", zhHans: "把严格正确性验证放进 simulator gate，把 host CoreText 保持为 report-only，并在产品 UI 里清楚展示 stage rollout 的故事。", zhHant: "把嚴格正確性驗證放進 simulator gate，讓 host CoreText 保持 report-only，並在產品 UI 中清楚展示 stage rollout 的脈絡。") }
    var feedCardDetail: String { value(en: "This is the card-shaped example teams use to verify line limit, truncation, and fill behavior before rollout.", ko: "이 카드는 팀이 실제 도입 전에 줄 수 제한, truncation, fill 동작을 확인할 때 쓰는 제품형 예시입니다.", ja: "このカードは、導入前に行数制限、truncation、fill の挙動を確認するための製品寄りサンプルです。", zhHans: "这是团队在 rollout 前验证行数限制、截断和 fill 行为时最接近产品形态的示例。", zhHant: "這張卡片是團隊在 rollout 前驗證行數限制、截斷與 fill 行為時最接近產品形態的範例。") }
    var feedCardTags: [String] { [value(en: "Tail truncation", ko: "끝 생략", ja: "末尾省略", zhHans: "尾部截断", zhHant: "尾端截斷"), "fillProposal", value(en: "Stage 1 renderer", ko: "Stage 1 렌더러", ja: "Stage 1 レンダラー", zhHans: "Stage 1 渲染", zhHant: "Stage 1 渲染")] }
    var feedChromeTitle: String { value(en: "Prepared Feed", ko: "Prepared 피드", ja: "Prepared フィード", zhHans: "Prepared 信息流", zhHant: "Prepared 動態") }
    var feedChromeSubtitle: String { value(en: "Summary + body copy", ko: "요약 + 본문", ja: "要約 + 本文", zhHans: "摘要 + 正文", zhHant: "摘要 + 正文") }
    var feedCommentsLabel: String { value(en: "14 comments", ko: "댓글 14개", ja: "コメント 14件", zhHans: "14 条评论", zhHant: "14 則留言") }

    var listRowTitle: String { value(en: "List Row Secondary Copy", ko: "리스트 행 보조 텍스트", ja: "リスト行の補助コピー", zhHans: "列表行次级文本", zhHant: "列表列次要文字") }
    var listRowEyebrow: String { value(en: "Deterministic self-sizing", ko: "결정적인 self-sizing", ja: "決定的な self-sizing", zhHans: "确定性自适应高度", zhHant: "確定性的自適應高度") }
    var listHeadline: String { value(en: "Self-sizing row note", ko: "self-sizing 행 메모", ja: "self-sizing 行メモ", zhHans: "自适应高度行备注", zhHant: "自適應列備註") }
    var listBody: String { value(en: "The same immutable payload can travel through width changes without rethinking the entire measurement path on every state update.", ko: "같은 immutable payload는 상태가 바뀔 때마다 전체 측정 경로를 다시 계산하지 않고도 폭 변화에 대응할 수 있습니다.", ja: "同じ immutable payload は、状態更新のたびに測定経路全体をやり直さずに幅変化へ追従できます。", zhHans: "同一份 immutable payload 可以在宽度变化时复用，而不必在每次状态更新时重走整条测量路径。", zhHant: "同一份 immutable payload 可以在寬度變化時重用，而不必在每次狀態更新時重走整條測量路徑。") }
    var listRowDetail: String { value(en: "List rows are where teams first feel the stage-0 to stage-1 story, because height prediction is what people notice immediately.", ko: "리스트 행은 팀이 Stage 0에서 Stage 1로 가는 이야기를 가장 빨리 체감하는 곳입니다. 사용자는 높이 예측부터 바로 느끼기 때문입니다.", ja: "リスト行は、チームが Stage 0 から Stage 1 への違いを最初に体感する場所です。人は高さ予測の違いをすぐに感じるからです。", zhHans: "列表行通常是团队最先感受到 Stage 0 到 Stage 1 差异的地方，因为用户会立刻注意到高度预测。", zhHant: "列表列通常是團隊最先感受到 Stage 0 到 Stage 1 差異的地方，因為使用者會立刻注意到高度預測。") }
    var listRowTags: [String] { [value(en: "Self-sizing", ko: "Self-sizing", ja: "Self-sizing", zhHans: "Self-sizing", zhHant: "Self-sizing"), value(en: "Prepared reuse", ko: "Prepared 재사용", ja: "Prepared 再利用", zhHans: "Prepared 复用", zhHant: "Prepared 重用"), value(en: "List UI", ko: "리스트 UI", ja: "リスト UI", zhHans: "列表 UI", zhHant: "列表 UI")] }
    var listChromeTitle: String { value(en: "Prepared row subtitle", ko: "Prepared 행 보조 텍스트", ja: "Prepared 行サブテキスト", zhHans: "Prepared 行副标题", zhHant: "Prepared 列副標題") }

    var calloutTitle: String { value(en: "Centered Status Callout", ko: "가운데 정렬 상태 콜아웃", ja: "中央揃えステータスコールアウト", zhHans: "居中状态提示", zhHant: "置中狀態提示") }
    var calloutEyebrow: String { value(en: "Alignment and compact truncation", ko: "정렬과 compact truncation", ja: "整列と compact truncation", zhHans: "对齐与紧凑截断", zhHant: "對齊與緊湊截斷") }
    var calloutBody: String { value(en: "Prepared surfaces stay narrow on purpose. They aim for reliable read-only copy, not full UILabel parity.", ko: "Prepared surface는 의도적으로 좁게 유지됩니다. 목표는 읽기 전용 텍스트의 신뢰성이지, UILabel 완전 호환이 아닙니다.", ja: "Prepared surface は意図的に狭く保たれます。目的は読み取り専用コピーの信頼性であり、UILabel 完全互換ではありません。", zhHans: "Prepared surface 被刻意保持得很窄。目标是提供可靠的只读文本，而不是完整的 UILabel 对等能力。", zhHant: "Prepared surface 被刻意維持得很窄。目標是提供可靠的唯讀文字，而不是完整的 UILabel 對等能力。") }
    var calloutDetail: String { value(en: "Use the alignment buttons here. The text should visibly shift inside the same prepared surface as you switch leading, center, and trailing placement.", ko: "여기서는 정렬 버튼을 눌러보세요. leading, center, trailing을 바꿀 때 같은 prepared surface 안에서 텍스트 위치가 눈에 띄게 이동해야 합니다.", ja: "ここでは整列ボタンを押してください。leading / center / trailing を切り替えると、同じ prepared surface 内で文字位置が目に見えて移動するはずです。", zhHans: "这里请切换对齐按钮。切到 leading、center、trailing 时，同一 prepared surface 内的文本位置应该明显移动。", zhHant: "這裡請切換對齊按鈕。切到 leading、center、trailing 時，同一 prepared surface 內的文字位置應該明顯移動。") }
    var calloutTags: [String] { [value(en: "Center alignment", ko: "가운데 정렬", ja: "中央揃え", zhHans: "居中对齐", zhHant: "置中對齊"), value(en: "2 lines", ko: "2줄", ja: "2行", zhHans: "2行", zhHant: "2行"), value(en: "Middle truncation", ko: "중간 생략", ja: "中央省略", zhHans: "中间截断", zhHant: "中間截斷")] }
    var calloutChromeTitle: String { value(en: "Prepared status copy", ko: "Prepared 상태 문구", ja: "Prepared ステータス文", zhHans: "Prepared 状态文案", zhHant: "Prepared 狀態文案") }

    var linkEyebrow: String { value(en: "Link handling", ko: "링크 처리", ja: "リンク処理", zhHans: "链接处理", zhHant: "連結處理") }
    var linkTitle: String { value(en: "Use the same renderer path and tap the controls around it", ko: "같은 렌더러 경로를 유지한 채 주변 컨트롤을 눌러보세요", ja: "同じレンダラ経路のまま周辺コントロールを操作できます", zhHans: "保持同一条渲染路径，再去点击周围的控制项", zhHant: "維持同一條渲染路徑，再去點擊周圍的控制項") }
    var linkDetail: String { value(en: "The link card should feel alive: align it, clamp it, change truncation, then tap the link and confirm the callback still comes through.", ko: "링크 카드는 살아 있어야 합니다. 정렬을 바꾸고, 줄 수를 제한하고, truncation을 바꾼 뒤 링크를 눌러 callback이 여전히 들어오는지 확인하세요.", ja: "リンクカードは生きているように感じられるべきです。整列、行数、truncation を変えた後、リンクを押して callback が通るか確認してください。", zhHans: "链接卡片应该是“活”的：改对齐、改行数、改截断，再点链接确认 callback 仍然能回来。", zhHant: "連結卡片應該是「活的」：改對齊、改行數、改截斷，再點連結確認 callback 仍然能回來。") }
    var linkTags: [String] { [value(en: "Interactive links", ko: "상호작용 링크", ja: "インタラクティブリンク", zhHans: "可交互链接", zhHant: "可互動連結"), value(en: "Center alignment", ko: "가운데 정렬", ja: "中央揃え", zhHans: "居中对齐", zhHant: "置中對齊"), value(en: "Line limit", ko: "줄 수 제한", ja: "行数制限", zhHans: "行数限制", zhHant: "行數限制")] }
    var linkBody: String { value(en: "Tap the migration guide to prove the SwiftUI bridge is still the UIKit prepared renderer underneath.", ko: "migration guide를 눌러 SwiftUI 브리지 아래에서도 여전히 UIKit prepared renderer가 동작하는지 확인해보세요.", ja: "migration guide を押して、SwiftUI ブリッジの下でも UIKit prepared renderer が使われていることを確認してください。", zhHans: "点击 migration guide，确认 SwiftUI bridge 底下仍然是 UIKit prepared renderer。", zhHant: "點擊 migration guide，確認 SwiftUI bridge 底下仍然是 UIKit prepared renderer。") }
    var linkTarget: String { "migration guide" }
    var localizedLinkedText: NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: linkBody,
            attributes: [.font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor.label]
        )
        let ns = attributed.string as NSString
        let range = ns.range(of: linkTarget)
        if range.location != NSNotFound {
            attributed.addAttribute(.link, value: URL(string: "https://example.com/migration-guide")!, range: range)
            attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        return attributed
    }
    var linkIdleStatus: String { value(en: "No link interaction yet.", ko: "아직 링크 상호작용이 없습니다.", ja: "まだリンク操作はありません。", zhHans: "还没有链接交互。", zhHant: "還沒有連結互動。") }
    var linkTappedPrefix: String { value(en: "Tapped", ko: "탭함", ja: "タップ", zhHans: "已点击", zhHant: "已點擊") }

    var whitespaceEyebrow: String { value(en: "Text contract", ko: "텍스트 계약", ja: "テキスト契約", zhHans: "文本约定", zhHant: "文字契約") }
    var whitespaceTitle: String { value(en: "Switch whitespace semantics on the same authored text", ko: "같은 작성 텍스트에서 whitespace semantics를 바꿔보세요", ja: "同じテキストで whitespace semantics を切り替えます", zhHans: "在同一段文本上切换 whitespace semantics", zhHant: "在同一段文字上切換 whitespace semantics") }
    var whitespaceDetail: String { value(en: "This should make it obvious that whitespace mode is an explicit product choice, not an invisible implementation detail.", ko: "whitespace mode가 보이지 않는 구현 세부사항이 아니라 명시적인 제품 선택이라는 점이 분명히 보여야 합니다.", ja: "whitespace mode が見えない実装詳細ではなく、明示的な製品上の選択であることが分かるべきです。", zhHans: "这里应该让人一眼看出，whitespace mode 是明确的产品选择，而不是隐藏的实现细节。", zhHant: "這裡應該讓人一眼看出，whitespace mode 是明確的產品選擇，而不是隱藏的實作細節。") }
    var whitespaceBody: String { value(en: "Status:\nReady    for\treview", ko: "상태:\n리뷰\t준비    완료", ja: "状態:\nレビュー\t準備    完了", zhHans: "状态:\n评审\t准备    完成", zhHant: "狀態:\n評審\t準備    完成") }
    var whitespaceLiteralTitle: String { "UIKit literal" }
    var whitespaceLiteralDetail: String { value(en: "Default mode. Explicit line breaks, tabs, and repeated spaces stay literal.", ko: "기본 모드입니다. 줄바꿈, 탭, 반복 공백을 그대로 유지합니다.", ja: "既定モードです。改行、タブ、連続スペースをそのまま保ちます。", zhHans: "默认模式。显式换行、制表符和重复空格都会按原样保留。", zhHant: "預設模式。顯式換行、定位鍵與重複空格都會如實保留。") }
    var whitespaceCSSTitle: String { "CSS normal" }
    var whitespaceCSSDetail: String { value(en: "Opt-in collapse semantics. Useful when you intentionally want web-style whitespace treatment.", ko: "opt-in collapse semantics입니다. 웹 스타일 whitespace 처리가 실제로 필요할 때만 씁니다.", ja: "opt-in の collapse semantics です。Web 風の whitespace 処理が本当に必要なときだけ使います。", zhHans: "可选的折叠语义。只有在你确实想要 Web 风格空白处理时才使用。", zhHant: "可選的折疊語義。只有在你確實需要 Web 風格空白處理時才使用。") }
    var whitespacePreWrapTitle: String { "pre-wrap" }
    var whitespacePreWrapDetail: String { value(en: "Opt-in preserved whitespace for code-like snippets, debug copy, or authored spacing.", ko: "코드 조각, 디버그 문구, 직접 작성한 간격을 보존해야 할 때 쓰는 opt-in 모드입니다.", ja: "コード風の断片、デバッグ用コピー、作者が意図した空白を保ちたいときの opt-in モードです。", zhHans: "用于代码片段、调试文案或需要保留作者空白意图的可选模式。", zhHant: "用於程式片段、除錯文案或需要保留作者空白意圖的可選模式。") }

    var widthLabEyebrow: String { value(en: "Width churn lab", ko: "폭 변화 실험실", ja: "幅変動ラボ", zhHans: "宽度变化实验室", zhHant: "寬度變化實驗室") }
    var widthLabTitle: String { value(en: "Keep the payload fixed and only move the proposal width", ko: "payload는 고정하고 proposal width만 움직여보세요", ja: "payload を固定したまま proposal width だけを動かします", zhHans: "保持 payload 不变，只调整 proposal width", zhHant: "保持 payload 不變，只調整 proposal width") }
    var widthLabDetail: String { value(en: "Use the slider or tap the width pills. The text should reflow immediately, and alignment changes should stay visible inside the same width-constrained surface.", ko: "슬라이더를 움직이거나 폭 버튼을 눌러보세요. 텍스트는 즉시 다시 흐르고, 정렬 변화도 같은 폭 제약 surface 안에서 눈에 보여야 합니다.", ja: "スライダーまたは幅ボタンを使ってください。テキストはすぐ再フローし、整列の変化も同じ幅制約サーフェス内で見えるはずです。", zhHans: "拖动滑块或点击宽度按钮。文本应该立刻重新排版，而对齐变化也应该在同一宽度约束 surface 内清楚可见。", zhHant: "拖動滑桿或點擊寬度按鈕。文字應該立刻重新排版，而對齊變化也應該在同一寬度約束 surface 內清楚可見。") }
    var preparedReuseChipLabel: String { value(en: "Prepared reuse", ko: "Prepared 재사용", ja: "Prepared 再利用", zhHans: "Prepared 复用", zhHant: "Prepared 重用") }
    var shrinkwrapEyebrow: String { value(en: "Shrinkwrap showdown", ko: "슈링크랩 대결", ja: "シュリンクラップ対決", zhHans: "收缩包裹对决", zhHant: "收縮包裹對決") }
    var shrinkwrapTitle: String { value(en: "CSS-style fit width vs exact same-line-count shrinkwrap", ko: "CSS식 fit 너비와 같은 줄 수를 유지하는 정확한 shrinkwrap 비교", ja: "CSS 風 fit 幅と同じ行数を保つ正確な shrinkwrap の比較", zhHans: "CSS 式 fit 宽度 vs 保持相同行数的精确 shrinkwrap", zhHant: "CSS 式 fit 寬度 vs 保持相同行數的精確 shrinkwrap") }
    var shrinkwrapDetail: String { value(en: "This mirrors the feel of the public shrinkwrap demo: one side sizes to the widest wrapped line, the other side searches for the narrowest width that preserves the same line count.", ko: "공개 shrinkwrap 데모의 느낌을 가져온 섹션입니다. 한쪽은 가장 긴 줄 기준으로 폭을 잡고, 다른 쪽은 같은 줄 수를 유지하는 가장 좁은 폭을 찾습니다.", ja: "公開 shrinkwrap デモの感覚を持ち込んだセクションです。片方は最も長い折り返し行に合わせ、もう片方は同じ行数を保つ最小幅を探します。", zhHans: "这个区块借用了公开 shrinkwrap demo 的感觉：一边按最宽换行行来定宽，另一边则寻找保持相同行数的最窄宽度。", zhHant: "這個區塊借用了公開 shrinkwrap demo 的感覺：一邊按最寬換行行來定寬，另一邊則尋找保持相同行數的最窄寬度。") }
    var shrinkwrapBody: String { value(en: "Shrinkwrap showdown. A wrapped paragraph often leaves dead space when the box simply follows the widest line. Prepared text can search for the tightest width that keeps the same line count and the same reading rhythm.", ko: "슈링크랩 대결입니다. 감싼 문단은 박스가 가장 긴 줄만 따라가면 종종 죽은 여백이 남습니다. prepared text는 같은 줄 수와 같은 읽기 리듬을 유지하는 가장 타이트한 폭을 찾을 수 있습니다.", ja: "シュリンクラップ対決です。折り返した段落は、箱が最も長い行だけに従うと無駄な余白が残りがちです。prepared text は同じ行数と読みのリズムを保つ最もタイトな幅を探せます。", zhHans: "这是 shrinkwrap 对决。段落在换行后，如果盒子只跟随最宽那一行，通常会留下很多空余。prepared text 可以搜索在保持相同行数和阅读节奏时最紧的宽度。", zhHant: "這是 shrinkwrap 對決。段落在換行後，如果盒子只跟隨最寬那一行，通常會留下很多空餘。prepared text 可以搜尋在保持相同行數與閱讀節奏時最緊的寬度。") }
    var shrinkwrapFitContentTitle: String { value(en: "Fit-content style", ko: "fit-content 스타일", ja: "fit-content 風", zhHans: "fit-content 风格", zhHant: "fit-content 風格") }
    var shrinkwrapFitContentDetail: String { value(en: "Sizes to the longest wrapped line.", ko: "가장 긴 줄 기준으로 폭을 잡습니다.", ja: "最も長い折り返し行に合わせます。", zhHans: "按照最宽的换行行来定宽。", zhHant: "按照最寬的換行行來定寬。") }
    var shrinkwrapPretextTitle: String { value(en: "prepared-text-ios shrinkwrap", ko: "prepared-text-ios shrinkwrap", ja: "prepared-text-ios shrinkwrap", zhHans: "prepared-text-ios shrinkwrap", zhHant: "prepared-text-ios shrinkwrap") }
    var shrinkwrapPretextDetail: String { value(en: "Searches the tightest width with the same line count.", ko: "같은 줄 수를 유지하는 가장 좁은 폭을 찾습니다.", ja: "同じ行数を保つ最小幅を探します。", zhHans: "寻找保持相同行数的最窄宽度。", zhHant: "尋找保持相同行數的最窄寬度。") }
    var shrinkwrapLinesLabel: String { value(en: "Lines", ko: "줄 수", ja: "行数", zhHans: "行数", zhHant: "行數") }
    var shrinkwrapFootnote: String { value(en: "This is still a read-only layout demo. The point is not to mimic CSS perfectly, but to show that prepared layout can make width negotiation visible and exact.", ko: "이것도 여전히 read-only 레이아웃 데모입니다. CSS를 완벽히 흉내 내려는 것이 아니라, prepared layout이 width negotiation을 눈에 보이게 그리고 정밀하게 만들 수 있다는 점을 보여주는 것이 목적입니다.", ja: "これもあくまで read-only レイアウトデモです。CSS を完全再現するのではなく、prepared layout が width negotiation を見える形で正確に扱えることを示すのが目的です。", zhHans: "这仍然只是一个只读布局 demo。重点不是完美模仿 CSS，而是展示 prepared layout 能把 width negotiation 做得可见且精确。", zhHant: "這仍然只是一個唯讀布局 demo。重點不是完美模仿 CSS，而是展示 prepared layout 能把 width negotiation 做得可見且精確。") }
    var playLabEyebrow: String { value(en: "Play lab", ko: "플레이 실험실", ja: "プレイラボ", zhHans: "玩法实验室", zhHant: "玩法實驗室") }
    var playLabTitle: String { value(en: "Make the same payload feel like a tiny game scene", ko: "같은 payload를 작은 게임 장면처럼 보이게 만들어보세요", ja: "同じ payload を小さなゲームシーンのように見せます", zhHans: "让同一份 payload 看起来像一个小游戏场景", zhHant: "讓同一份 payload 看起來像一個小型遊戲場景") }
    var playLabDetail: String { value(en: "The Threads post theme was simple: ordinary text starts feeling playful once width negotiation becomes visible. This section leans into that idea without pretending the library became a game engine.", ko: "Threads 포스트의 핵심은 단순했습니다. 평범한 텍스트도 width negotiation이 눈에 보이기 시작하면 꽤 장난감처럼 느껴진다는 점입니다. 이 섹션은 그 방향만 적극적으로 가져오되, 라이브러리가 게임 엔진인 척하지는 않습니다.", ja: "Threads 投稿のテーマは単純でした。普通のテキストでも、width negotiation が見えるようになると遊び道具のように感じられるという点です。このセクションはその方向だけを強め、ライブラリがゲームエンジンになったかのようには見せません。", zhHans: "Threads 帖子的主题很简单：一旦宽度协商变得可见，普通文本也会开始显得像在“玩”。这个区块只强化这种感觉，不会假装库本身变成了游戏引擎。", zhHant: "Threads 貼文的主題很簡單：一旦寬度協商變得可見，普通文字也會開始顯得像在「玩」。這個區塊只強化這種感覺，不會假裝函式庫本身變成了遊戲引擎。") }
    var motionControlTitle: String { value(en: "Motion", ko: "움직임", ja: "動き", zhHans: "动态", zhHant: "動態") }
    var playLabLead: String { value(en: "Play lab scene.", ko: "플레이 실험실 장면.", ja: "プレイラボのシーン。", zhHans: "玩法实验场景。", zhHant: "玩法實驗場景。") }
    var playLabBody: String { value(en: " The text itself stays fixed. Only width proposals, alignment, and line-break policy keep shifting, which is enough to make the renderer feel more like an interaction toy than a static label.", ko: " 텍스트 자체는 고정되어 있습니다. 바뀌는 것은 width proposal, 정렬, 줄바꿈 정책뿐인데도, 그 정도만으로 렌더러가 정적인 라벨보다 작은 인터랙션 장난감처럼 느껴집니다.", ja: " テキスト自体は固定です。変わるのは width proposal、整列、改行ポリシーだけですが、それだけでもレンダラーは静的なラベルより小さなインタラクショントイのように感じられます。", zhHans: " 文本本身保持不变。变化的只有 width proposal、对齐方式和换行策略，但这已经足以让渲染器看起来更像一个互动玩具，而不是静态标签。", zhHant: " 文字本身保持不變。變化的只有 width proposal、對齊方式與換行策略，但這已經足以讓渲染器看起來更像一個互動玩具，而不是靜態標籤。") }
    var playLabFootnote: String { value(en: "This is still the same read-only prepared renderer. The trick is exposing width churn and line policy changes as visible motion.", ko: "여전히 같은 read-only prepared renderer입니다. 차이는 width churn과 줄 정책 변화를 눈에 보이는 움직임으로 드러냈다는 점입니다.", ja: "これはあくまで同じ read-only prepared renderer です。違いは、width churn と改行ポリシーの変化を見える動きにしたことです。", zhHans: "这仍然是同一个只读 prepared renderer。区别只是把 width churn 和换行策略变化显性化成了动态。", zhHant: "這仍然是同一個唯讀 prepared renderer。差別只是把 width churn 與換行策略變化顯性化成了動態。") }

    private func value(en: String, ko: String, ja: String, zhHans: String, zhHant: String) -> String {
        switch language {
        case .english: return en
        case .korean: return ko
        case .japanese: return ja
        case .chineseSimplified: return zhHans
        case .chineseTraditional: return zhHant
        }
    }
}

private struct CapabilityChipRow: View {
    let tags: [String]
    let tint: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    CapabilityChip(text: tag, tint: tint)
                }
            }
        }
    }
}

private struct CapabilityChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}
#endif
