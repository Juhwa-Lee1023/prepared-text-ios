#if canImport(UIKit) && !os(macOS)
import PretextCore
import UIKit

private enum PreparedUIKitDemoPalette {
    static func dynamic(_ light: UIColor, _ dark: UIColor) -> UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }

    static let heroBackground = dynamic(
        UIColor(red: 0.15, green: 0.23, blue: 0.43, alpha: 1.0),
        UIColor(red: 0.10, green: 0.14, blue: 0.24, alpha: 1.0)
    )
    static let heroSecondaryText = dynamic(
        UIColor.white.withAlphaComponent(0.88),
        UIColor.white.withAlphaComponent(0.82)
    )
    static let heroChipBackground = dynamic(
        UIColor.white.withAlphaComponent(0.14),
        UIColor.white.withAlphaComponent(0.12)
    )
    static let heroChipSecondaryText = dynamic(
        UIColor.white.withAlphaComponent(0.72),
        UIColor.white.withAlphaComponent(0.68)
    )
    static let previewSurface = dynamic(
        UIColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 1.0),
        UIColor(red: 0.14, green: 0.19, blue: 0.26, alpha: 1.0)
    )
    static let featureSurface = dynamic(
        UIColor(red: 0.89, green: 0.97, blue: 0.95, alpha: 1.0),
        UIColor(red: 0.12, green: 0.21, blue: 0.20, alpha: 1.0)
    )
    static let obstacleSurface = dynamic(
        UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0),
        UIColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)
    )
    static let obstacleStroke = dynamic(
        UIColor.black.withAlphaComponent(0.08),
        UIColor.white.withAlphaComponent(0.12)
    )
}

public struct PreparedTextUIKitDemoItem: Hashable {
    public var title: String
    public var subtitle: String
    public var note: String
    public var body: NSAttributedString
    public var whiteSpaceMode: WhiteSpaceMode
    public var surfaceMode: PreparedTextSurfaceMode
    public var sourceID: PreparedTextSourceID
    public var numberOfLines: Int
    public var lineBreakMode: NSLineBreakMode
    public var textAlignment: NSTextAlignment
    public var tintColor: UIColor
    public var surfaceColor: UIColor
    public var capabilityTags: [String]

    public init(
        title: String,
        subtitle: String,
        note: String,
        body: NSAttributedString,
        whiteSpaceMode: WhiteSpaceMode = .uikitLiteral,
        surfaceMode: PreparedTextSurfaceMode = .stage1Prepared,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        textAlignment: NSTextAlignment = .natural,
        tintColor: UIColor = .systemBlue,
        surfaceColor: UIColor = .secondarySystemBackground,
        capabilityTags: [String] = [],
        sourceID: PreparedTextSourceID? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.note = note
        self.body = body
        self.whiteSpaceMode = whiteSpaceMode
        self.surfaceMode = surfaceMode
        self.numberOfLines = max(numberOfLines, 0)
        self.lineBreakMode = lineBreakMode
        self.textAlignment = textAlignment
        self.tintColor = tintColor
        self.surfaceColor = surfaceColor
        self.capabilityTags = capabilityTags
        self.sourceID = sourceID ?? PreparedTextSourceID(title)
    }

    public static func == (lhs: PreparedTextUIKitDemoItem, rhs: PreparedTextUIKitDemoItem) -> Bool {
        lhs.title == rhs.title &&
            lhs.subtitle == rhs.subtitle &&
            lhs.note == rhs.note &&
            lhs.whiteSpaceMode == rhs.whiteSpaceMode &&
            lhs.surfaceMode == rhs.surfaceMode &&
            lhs.numberOfLines == rhs.numberOfLines &&
            lhs.lineBreakMode == rhs.lineBreakMode &&
            lhs.textAlignment == rhs.textAlignment &&
            lhs.tintColor == rhs.tintColor &&
            lhs.surfaceColor == rhs.surfaceColor &&
            lhs.capabilityTags == rhs.capabilityTags &&
            lhs.sourceID == rhs.sourceID &&
            lhs.body.isEqual(to: rhs.body)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(note)
        hasher.combine(body.string)
        hasher.combine(whiteSpaceMode)
        hasher.combine(surfaceMode)
        hasher.combine(numberOfLines)
        hasher.combine(lineBreakMode.rawValue)
        hasher.combine(textAlignment.rawValue)
        hasher.combine(PreparedTextUIKitDemoItem.stableColorDescriptor(for: tintColor, interfaceStyle: .light))
        hasher.combine(PreparedTextUIKitDemoItem.stableColorDescriptor(for: tintColor, interfaceStyle: .dark))
        hasher.combine(PreparedTextUIKitDemoItem.stableColorDescriptor(for: surfaceColor, interfaceStyle: .light))
        hasher.combine(PreparedTextUIKitDemoItem.stableColorDescriptor(for: surfaceColor, interfaceStyle: .dark))
        hasher.combine(capabilityTags)
        hasher.combine(sourceID)
    }

    private static func stableColorDescriptor(
        for color: UIColor,
        interfaceStyle: UIUserInterfaceStyle
    ) -> [CGFloat] {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: interfaceStyle))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return [red, green, blue, alpha].map { ($0 * 10_000).rounded() / 10_000 }
        }

        var white: CGFloat = 0
        if resolved.getWhite(&white, alpha: &alpha) {
            let value = (white * 10_000).rounded() / 10_000
            let resolvedAlpha = (alpha * 10_000).rounded() / 10_000
            return [value, value, value, resolvedAlpha]
        }

        let cgColor = resolved.cgColor
        let model = CGFloat(cgColor.colorSpace?.model.rawValue ?? -1)
        let components = (cgColor.components ?? []).map { ($0 * 10_000).rounded() / 10_000 }
        return [model] + components
    }

    public static func makeSamples(
        language: PreparedTextDemoLanguage = .english,
        count: Int? = nil
    ) -> [PreparedTextUIKitDemoItem] {
        let copy = PreparedTextUIKitCopy(language: language)
        let bodyFont = UIFont.systemFont(ofSize: 17)
        let boldFont = UIFont.boldSystemFont(ofSize: 17)

        let stage0Rollout = NSAttributedString(
            string: copy.stage0RolloutBody,
            attributes: [.font: bodyFont]
        )

        let stage1Bubble = NSMutableAttributedString(
            string: copy.stage1BubbleBody,
            attributes: [.font: bodyFont]
        )
        let bubbleLinkRange = (stage1Bubble.string as NSString).range(of: copy.releaseGuideLinkText)
        if bubbleLinkRange.location != NSNotFound, bubbleLinkRange.length > 0 {
            stage1Bubble.addAttribute(.link, value: URL(string: "https://example.com/release-guide")!, range: bubbleLinkRange)
            stage1Bubble.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: bubbleLinkRange)
        }

        let feedSummary = NSMutableAttributedString(
            string: "\(copy.feedSummaryTitle)\n",
            attributes: [.font: boldFont]
        )
        feedSummary.append(
            NSAttributedString(
                string: copy.feedSummaryBody,
                attributes: [.font: bodyFont]
            )
        )

        let stage0List = NSAttributedString(
            string: copy.stage0ListBody,
            attributes: [.font: bodyFont]
        )

        let preWrapCard = NSAttributedString(
            string: copy.whitespaceBody,
            attributes: [.font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)]
        )

        let centeredCallout = NSAttributedString(
            string: copy.centeredCalloutBody,
            attributes: [.font: bodyFont]
        )

        let baseItems = [
            PreparedTextUIKitDemoItem(
                title: copy.stage0RolloutTitle,
                subtitle: copy.stage0RolloutSubtitle,
                note: copy.stage0RolloutNote,
                body: stage0Rollout,
                surfaceMode: .stage0MeasureOnly,
                lineBreakMode: .byWordWrapping,
                tintColor: UIColor(red: 0.15, green: 0.43, blue: 0.81, alpha: 1.0),
                surfaceColor: PreparedUIKitDemoPalette.dynamic(
                    UIColor(red: 0.91, green: 0.95, blue: 1.0, alpha: 1.0),
                    UIColor(red: 0.14, green: 0.19, blue: 0.27, alpha: 1.0)
                ),
                capabilityTags: ["Stage 0", "Self-sizing", "UILabel"],
                sourceID: PreparedTextSourceID("uikit-stage0-rollout")
            ),
            PreparedTextUIKitDemoItem(
                title: copy.stage1BubbleTitle,
                subtitle: copy.stage1BubbleSubtitle,
                note: copy.stage1BubbleNote,
                body: stage1Bubble,
                surfaceMode: .stage1Prepared,
                numberOfLines: 3,
                lineBreakMode: .byTruncatingTail,
                tintColor: UIColor(red: 0.12, green: 0.56, blue: 0.52, alpha: 1.0),
                surfaceColor: PreparedUIKitDemoPalette.dynamic(
                    UIColor(red: 0.89, green: 0.97, blue: 0.95, alpha: 1.0),
                    UIColor(red: 0.12, green: 0.20, blue: 0.19, alpha: 1.0)
                ),
                capabilityTags: ["Stage 1", "Links", "Bubble"],
                sourceID: PreparedTextSourceID("uikit-stage1-bubble")
            ),
            PreparedTextUIKitDemoItem(
                title: copy.feedCardTitle,
                subtitle: copy.feedCardSubtitle,
                note: copy.feedCardNote,
                body: feedSummary,
                surfaceMode: .stage1Prepared,
                numberOfLines: 3,
                lineBreakMode: .byTruncatingTail,
                tintColor: UIColor(red: 0.31, green: 0.52, blue: 0.20, alpha: 1.0),
                surfaceColor: PreparedUIKitDemoPalette.dynamic(
                    UIColor(red: 0.95, green: 0.97, blue: 0.91, alpha: 1.0),
                    UIColor(red: 0.15, green: 0.20, blue: 0.14, alpha: 1.0)
                ),
                capabilityTags: ["Tail ellipsis", "Feed", "Prepared sizing"],
                sourceID: PreparedTextSourceID("uikit-feed-summary")
            ),
            PreparedTextUIKitDemoItem(
                title: copy.stage0ListTitle,
                subtitle: copy.stage0ListSubtitle,
                note: copy.stage0ListNote,
                body: stage0List,
                surfaceMode: .stage0MeasureOnly,
                numberOfLines: 2,
                lineBreakMode: .byTruncatingTail,
                tintColor: UIColor(red: 0.46, green: 0.34, blue: 0.78, alpha: 1.0),
                surfaceColor: PreparedUIKitDemoPalette.dynamic(
                    UIColor(red: 0.95, green: 0.94, blue: 0.99, alpha: 1.0),
                    UIColor(red: 0.18, green: 0.15, blue: 0.24, alpha: 1.0)
                ),
                capabilityTags: ["Cached measure", "List row", "Reuse-safe"],
                sourceID: PreparedTextSourceID("uikit-stage0-list-detail")
            ),
            PreparedTextUIKitDemoItem(
                title: copy.whitespaceTitle,
                subtitle: copy.whitespaceSubtitle,
                note: copy.whitespaceNote,
                body: preWrapCard,
                whiteSpaceMode: .preWrap,
                surfaceMode: .stage1Prepared,
                lineBreakMode: .byWordWrapping,
                tintColor: UIColor(red: 0.76, green: 0.40, blue: 0.13, alpha: 1.0),
                surfaceColor: PreparedUIKitDemoPalette.dynamic(
                    UIColor(red: 0.99, green: 0.94, blue: 0.90, alpha: 1.0),
                    UIColor(red: 0.26, green: 0.18, blue: 0.13, alpha: 1.0)
                ),
                capabilityTags: ["preWrap", "Tabs", "Spaces"],
                sourceID: PreparedTextSourceID("uikit-prewrap-contract")
            ),
            PreparedTextUIKitDemoItem(
                title: copy.centeredCalloutTitle,
                subtitle: copy.centeredCalloutSubtitle,
                note: copy.centeredCalloutNote,
                body: centeredCallout,
                surfaceMode: .stage1Prepared,
                numberOfLines: 2,
                lineBreakMode: .byTruncatingMiddle,
                textAlignment: .center,
                tintColor: UIColor(red: 0.72, green: 0.37, blue: 0.15, alpha: 1.0),
                surfaceColor: PreparedUIKitDemoPalette.dynamic(
                    UIColor(red: 0.99, green: 0.95, blue: 0.90, alpha: 1.0),
                    UIColor(red: 0.24, green: 0.17, blue: 0.13, alpha: 1.0)
                ),
                capabilityTags: ["Center", "2 lines", "Middle truncation"],
                sourceID: PreparedTextSourceID("uikit-centered-callout")
            ),
        ]

        guard let count else {
            return baseItems
        }

        if count <= 0 {
            return []
        }

        if count <= baseItems.count {
            return Array(baseItems.prefix(count))
        }

        return (0..<count).map { index in
            var item = baseItems[index % baseItems.count]
            item.sourceID = PreparedTextSourceID("\(item.sourceID.rawValue)-\(index)")
            return item
        }
    }
}

@MainActor
public protocol PreparedTextUIKitEmbeddablePage: AnyObject {
    var embeddedContentHeightDidChange: ((CGFloat) -> Void)? { get set }
    func setEmbeddedScrollingEnabled(_ isEnabled: Bool)
    func invalidateEmbeddedLayout()
}

public final class PreparedTextOverviewDemoViewController: UIViewController, PreparedTextUIKitEmbeddablePage {
    private let copy: PreparedTextUIKitCopy
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let stageControl = UISegmentedControl(items: ["Stage 0", "Stage 1"])
    private let widthSlider = UISlider()
    private let heightSlider = UISlider()
    private let widthValueLabel = UILabel()
    private let heightValueLabel = UILabel()
    private let stageDescriptionLabel = UILabel()
    private let previewHolder = UIView()
    private let previewChromeView = UIView()
    private lazy var previewWidthConstraint = previewChromeView.widthAnchor.constraint(equalToConstant: 232)
    private lazy var previewHeightConstraint = previewChromeView.heightAnchor.constraint(greaterThanOrEqualToConstant: 188)
    private let stage0PreviewLabel = MeasurementCachingLabel()
    private let stage1PreviewLabel = PreparedLabelView()

    private let featurePreviewLabel = PreparedLabelView()
    private let featureStatusLabel = UILabel()
    private var preferredPreviewWidth: CGFloat
    private var preferredPreviewHeight: CGFloat
    private var lastReportedEmbeddedHeight: CGFloat = 0

    public var embeddedContentHeightDidChange: ((CGFloat) -> Void)?

    public init(
        language: PreparedTextDemoLanguage = .english,
        previewWidth: CGFloat = 232,
        previewHeight: CGFloat = 188
    ) {
        self.copy = PreparedTextUIKitCopy(language: language)
        self.preferredPreviewWidth = previewWidth
        self.preferredPreviewHeight = previewHeight
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        self.copy = PreparedTextUIKitCopy(language: .english)
        self.preferredPreviewWidth = 232
        self.preferredPreviewHeight = 188
        super.init(coder: coder)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = copy.overviewScreenTitle
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .systemGroupedBackground

        configureScrollLayout()
        buildHero()
        buildStageLabPanel()
        buildFeaturePanel()
        buildWhitespacePanel()
        updateStagePreview()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        reportEmbeddedContentHeightIfNeeded()
    }

    public func apply(previewWidth: CGFloat, previewHeight: CGFloat) {
        preferredPreviewWidth = previewWidth
        preferredPreviewHeight = previewHeight
        if isViewLoaded {
            widthSlider.value = Float(previewWidth)
            heightSlider.value = Float(previewHeight)
            updateStagePreview()
            invalidateEmbeddedLayout()
        }
    }

    public func setEmbeddedScrollingEnabled(_ isEnabled: Bool) {
        scrollView.isScrollEnabled = isEnabled
        scrollView.alwaysBounceVertical = isEnabled
        scrollView.showsVerticalScrollIndicator = isEnabled
        invalidateEmbeddedLayout()
    }

    public func invalidateEmbeddedLayout() {
        guard isViewLoaded else {
            return
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
        reportEmbeddedContentHeightIfNeeded(force: true)
    }

    private func configureScrollLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    private func buildHero() {
        let hero = UIView()
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.backgroundColor = PreparedUIKitDemoPalette.heroBackground
        hero.layer.cornerRadius = 28
        hero.layer.cornerCurve = .continuous

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        titleLabel.text = copy.heroTitle

        let detailLabel = UILabel()
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = PreparedUIKitDemoPalette.heroSecondaryText
        detailLabel.numberOfLines = 0
        detailLabel.text = copy.heroDetail

        let chipRow = UIStackView()
        chipRow.axis = .horizontal
        chipRow.spacing = 8
        chipRow.translatesAutoresizingMaskIntoConstraints = false
        chipRow.addArrangedSubview(makeHeroChip(title: copy.heroChipRolloutTitle, value: copy.heroChipRolloutValue))
        chipRow.addArrangedSubview(makeHeroChip(title: copy.heroChipSurfaceTitle, value: copy.heroChipSurfaceValue))
        chipRow.addArrangedSubview(makeHeroChip(title: copy.heroChipContractTitle, value: copy.heroChipContractValue))

        hero.addSubview(titleLabel)
        hero.addSubview(detailLabel)
        hero.addSubview(chipRow)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: hero.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -20),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 20),
            detailLabel.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -20),

            chipRow.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 16),
            chipRow.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 20),
            chipRow.trailingAnchor.constraint(lessThanOrEqualTo: hero.trailingAnchor, constant: -20),
            chipRow.bottomAnchor.constraint(equalTo: hero.bottomAnchor, constant: -20),
        ])

        contentStack.addArrangedSubview(hero)
    }

    private func buildStageLabPanel() {
        let panel = PreparedDemoPanelView(
            eyebrow: copy.rolloutEyebrow,
            title: copy.rolloutTitle,
            detail: copy.rolloutDetail
        )
        contentStack.addArrangedSubview(panel)

        stageControl.selectedSegmentIndex = 1
        stageControl.setTitle(copy.stage0Label, forSegmentAt: 0)
        stageControl.setTitle(copy.stage1Label, forSegmentAt: 1)
        stageControl.addTarget(self, action: #selector(handleStageControlChanged), for: .valueChanged)

        widthSlider.minimumValue = 140
        widthSlider.maximumValue = 320
        widthSlider.value = Float(preferredPreviewWidth)
        widthSlider.addTarget(self, action: #selector(handleWidthSliderChanged), for: .valueChanged)

        heightSlider.minimumValue = 140
        heightSlider.maximumValue = 280
        heightSlider.value = Float(preferredPreviewHeight)
        heightSlider.addTarget(self, action: #selector(handleHeightSliderChanged), for: .valueChanged)

        widthValueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        widthValueLabel.textColor = .secondaryLabel
        heightValueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        heightValueLabel.textColor = .secondaryLabel

        stageDescriptionLabel.font = .preferredFont(forTextStyle: .footnote)
        stageDescriptionLabel.adjustsFontForContentSizeCategory = true
        stageDescriptionLabel.textColor = .secondaryLabel
        stageDescriptionLabel.numberOfLines = 0

        let controlRow = UIStackView(arrangedSubviews: [stageControl, widthValueLabel])
        controlRow.axis = .horizontal
        controlRow.spacing = 12
        controlRow.alignment = .center

        let heightRow = UIStackView(arrangedSubviews: [UILabel(), heightValueLabel])
        if let label = heightRow.arrangedSubviews.first as? UILabel {
            label.font = .preferredFont(forTextStyle: .caption1)
            label.textColor = .secondaryLabel
            label.text = copy.previewHeightLabel
        }
        heightRow.axis = .horizontal
        heightRow.spacing = 12
        heightRow.alignment = .center

        previewHolder.translatesAutoresizingMaskIntoConstraints = false
        previewChromeView.translatesAutoresizingMaskIntoConstraints = false
        previewChromeView.backgroundColor = PreparedUIKitDemoPalette.previewSurface
        previewChromeView.layer.cornerRadius = 20
        previewChromeView.layer.cornerCurve = .continuous

        stage0PreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        stage0PreviewLabel.numberOfLines = 0

        stage1PreviewLabel.translatesAutoresizingMaskIntoConstraints = false

        previewHolder.addSubview(previewChromeView)
        previewChromeView.addSubview(stage0PreviewLabel)
        previewChromeView.addSubview(stage1PreviewLabel)

        NSLayoutConstraint.activate([
            previewChromeView.topAnchor.constraint(equalTo: previewHolder.topAnchor),
            previewChromeView.centerXAnchor.constraint(equalTo: previewHolder.centerXAnchor),
            previewChromeView.bottomAnchor.constraint(equalTo: previewHolder.bottomAnchor),
            previewWidthConstraint,
            previewHeightConstraint,

            stage0PreviewLabel.topAnchor.constraint(equalTo: previewChromeView.topAnchor, constant: 16),
            stage0PreviewLabel.leadingAnchor.constraint(equalTo: previewChromeView.leadingAnchor, constant: 16),
            stage0PreviewLabel.trailingAnchor.constraint(equalTo: previewChromeView.trailingAnchor, constant: -16),
            stage0PreviewLabel.bottomAnchor.constraint(equalTo: previewChromeView.bottomAnchor, constant: -16),

            stage1PreviewLabel.topAnchor.constraint(equalTo: previewChromeView.topAnchor, constant: 16),
            stage1PreviewLabel.leadingAnchor.constraint(equalTo: previewChromeView.leadingAnchor, constant: 16),
            stage1PreviewLabel.trailingAnchor.constraint(equalTo: previewChromeView.trailingAnchor, constant: -16),
            stage1PreviewLabel.bottomAnchor.constraint(equalTo: previewChromeView.bottomAnchor, constant: -16),
        ])

        panel.contentStack.addArrangedSubview(controlRow)
        panel.contentStack.addArrangedSubview(widthSlider)
        panel.contentStack.addArrangedSubview(heightRow)
        panel.contentStack.addArrangedSubview(heightSlider)
        panel.contentStack.addArrangedSubview(previewHolder)
        panel.contentStack.addArrangedSubview(stageDescriptionLabel)
    }

    private func buildFeaturePanel() {
        let panel = PreparedDemoPanelView(
            eyebrow: copy.rendererEyebrow,
            title: copy.rendererTitle,
            detail: copy.rendererDetail
        )
        contentStack.addArrangedSubview(panel)

        let chipRow = UIStackView()
        chipRow.axis = .horizontal
        chipRow.spacing = 8
        chipRow.addArrangedSubview(makeTagChip(text: "Links", tintColor: UIColor(red: 0.13, green: 0.56, blue: 0.52, alpha: 1.0)))
        chipRow.addArrangedSubview(makeTagChip(text: "Center alignment", tintColor: UIColor(red: 0.13, green: 0.56, blue: 0.52, alpha: 1.0)))
        chipRow.addArrangedSubview(makeTagChip(text: "Tail truncation", tintColor: UIColor(red: 0.13, green: 0.56, blue: 0.52, alpha: 1.0)))

        let previewChromeView = UIView()
        previewChromeView.translatesAutoresizingMaskIntoConstraints = false
        previewChromeView.backgroundColor = PreparedUIKitDemoPalette.featureSurface
        previewChromeView.layer.cornerRadius = 18
        previewChromeView.layer.cornerCurve = .continuous

        featurePreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewChromeView.addSubview(featurePreviewLabel)
        NSLayoutConstraint.activate([
            featurePreviewLabel.topAnchor.constraint(equalTo: previewChromeView.topAnchor, constant: 16),
            featurePreviewLabel.leadingAnchor.constraint(equalTo: previewChromeView.leadingAnchor, constant: 16),
            featurePreviewLabel.trailingAnchor.constraint(equalTo: previewChromeView.trailingAnchor, constant: -16),
            featurePreviewLabel.bottomAnchor.constraint(equalTo: previewChromeView.bottomAnchor, constant: -16),
        ])

        featureStatusLabel.font = .preferredFont(forTextStyle: .footnote)
        featureStatusLabel.adjustsFontForContentSizeCategory = true
        featureStatusLabel.textColor = .secondaryLabel
        featureStatusLabel.numberOfLines = 0
        featureStatusLabel.text = copy.rendererStatusIdle

        let attributed = NSMutableAttributedString(
            string: copy.rendererPreviewBody,
            attributes: [.font: UIFont.systemFont(ofSize: 17)]
        )
        let linkRange = (attributed.string as NSString).range(of: copy.migrationGuideLinkText)
        if linkRange.location != NSNotFound, linkRange.length > 0 {
            attributed.addAttribute(.link, value: URL(string: "https://example.com/migration-guide")!, range: linkRange)
            attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkRange)
        }

        featurePreviewLabel.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: attributed,
                sourceID: PreparedTextSourceID("uikit-overview-feature-link"),
                whiteSpaceMode: .uikitLiteral,
                numberOfLines: 2,
                lineBreakMode: .byTruncatingTail,
                textAlignment: .center,
                automaticallyOpensLinks: false,
                linkTapHandler: { [weak self] url in
                    self?.featureStatusLabel.text = "\(self?.copy.rendererStatusTappedPrefix ?? "Tapped") \(url.lastPathComponent)"
                }
            )
        )

        panel.contentStack.addArrangedSubview(chipRow)
        panel.contentStack.addArrangedSubview(previewChromeView)
        panel.contentStack.addArrangedSubview(featureStatusLabel)
    }

    private func buildWhitespacePanel() {
        let panel = PreparedDemoPanelView(
            eyebrow: copy.whitespaceEyebrow,
            title: copy.whitespacePanelTitle,
            detail: copy.whitespacePanelDetail
        )
        contentStack.addArrangedSubview(panel)

        let sampleText = NSAttributedString(
            string: copy.whitespaceBody,
            attributes: [.font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)]
        )

        let literal = PreparedWhitespaceModeRowView(
            title: copy.whitespaceLiteralTitle,
            detail: copy.whitespaceLiteralDetail,
            mode: .uikitLiteral,
            tintColor: UIColor(red: 0.16, green: 0.42, blue: 0.81, alpha: 1.0),
            text: sampleText,
            sourceID: PreparedTextSourceID("uikit-overview-literal")
        )
        let cssNormal = PreparedWhitespaceModeRowView(
            title: copy.whitespaceCSSNormalTitle,
            detail: copy.whitespaceCSSNormalDetail,
            mode: .cssNormal,
            tintColor: UIColor(red: 0.75, green: 0.44, blue: 0.15, alpha: 1.0),
            text: sampleText,
            sourceID: PreparedTextSourceID("uikit-overview-css-normal")
        )
        let preWrap = PreparedWhitespaceModeRowView(
            title: copy.whitespacePreWrapTitle,
            detail: copy.whitespacePreWrapDetail,
            mode: .preWrap,
            tintColor: UIColor(red: 0.31, green: 0.55, blue: 0.23, alpha: 1.0),
            text: sampleText,
            sourceID: PreparedTextSourceID("uikit-overview-prewrap")
        )

        panel.contentStack.addArrangedSubview(literal)
        panel.contentStack.addArrangedSubview(cssNormal)
        panel.contentStack.addArrangedSubview(preWrap)
    }

    @objc private func handleStageControlChanged() {
        updateStagePreview()
    }

    @objc private func handleWidthSliderChanged() {
        updateStagePreview()
    }

    @objc private func handleHeightSliderChanged() {
        updateStagePreview()
    }

    private func updateStagePreview() {
        let previewText = NSMutableAttributedString(
            string: "\(copy.rolloutPreviewTitle)\n",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 17)]
        )
        previewText.append(
            NSAttributedString(
                string: copy.rolloutPreviewBody,
                attributes: [.font: UIFont.systemFont(ofSize: 17)]
            )
        )

        let width = CGFloat(widthSlider.value.rounded())
        let height = CGFloat(heightSlider.value.rounded())
        previewWidthConstraint.constant = width
        previewHeightConstraint.constant = height
        widthValueLabel.text = "\(Int(width))pt"
        heightValueLabel.text = "\(Int(height))pt"

        stage0PreviewLabel.attributedText = previewText
        stage0PreviewLabel.sourceID = PreparedTextSourceID("uikit-overview-stage0")
        stage0PreviewLabel.numberOfLines = 0
        stage0PreviewLabel.lineBreakMode = .byWordWrapping
        stage0PreviewLabel.textAlignment = .natural

        stage1PreviewLabel.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: previewText,
                sourceID: PreparedTextSourceID("uikit-overview-stage1"),
                whiteSpaceMode: .uikitLiteral,
                numberOfLines: 0,
                lineBreakMode: .byWordWrapping
            )
        )

        let showingStage0 = stageControl.selectedSegmentIndex == 0
        stage0PreviewLabel.isHidden = !showingStage0
        stage1PreviewLabel.isHidden = showingStage0
        stageDescriptionLabel.text = showingStage0
            ? copy.stage0Description
            : copy.stage1Description
    }

    private func makeHeroChip(title: String, value: String) -> UIView {
        let container = UIView()
        container.backgroundColor = PreparedUIKitDemoPalette.heroChipBackground
        container.layer.cornerRadius = 16
        container.layer.cornerCurve = .continuous

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = PreparedUIKitDemoPalette.heroChipSecondaryText
        titleLabel.text = title.uppercased()

        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        valueLabel.textColor = .white
        valueLabel.text = value

        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])
        return container
    }

    private func makeTagChip(text: String, tintColor: UIColor) -> UIView {
        let label = PreparedPillLabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = tintColor
        label.backgroundColor = tintColor.withAlphaComponent(0.12)
        label.layer.cornerRadius = 12
        label.layer.cornerCurve = .continuous
        return label
    }

    private func reportEmbeddedContentHeightIfNeeded(force: Bool = false) {
        guard let embeddedContentHeightDidChange else {
            return
        }

        let height = ceil(scrollView.contentSize.height + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom)
        guard height > 0 else {
            return
        }

        if force == false, abs(height - lastReportedEmbeddedHeight) < 0.5 {
            return
        }

        lastReportedEmbeddedHeight = height
        embeddedContentHeightDidChange(height)
    }
}

public final class PreparedTextTableViewCell: UITableViewCell {
    public static let reuseIdentifier = "PreparedTextTableViewCell"

    private let cardView = PreparedTextDemoSurfaceCardView()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    public func configure(with item: PreparedTextUIKitDemoItem) {
        cardView.configure(with: item)
    }

    private func configure() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.addSubview(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }
}

public final class PreparedTextCollectionViewCell: UICollectionViewCell {
    public static let reuseIdentifier = "PreparedTextCollectionViewCell"

    private let cardView = PreparedTextDemoSurfaceCardView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    public override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        setNeedsLayout()
        layoutIfNeeded()
        let target = CGSize(width: layoutAttributes.size.width, height: UIView.layoutFittingCompressedSize.height)
        let fitted = contentView.systemLayoutSizeFitting(
            target,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let copy = layoutAttributes.copy() as? UICollectionViewLayoutAttributes ?? layoutAttributes
        copy.size = CGSize(width: layoutAttributes.size.width, height: ceil(fitted.height))
        return copy
    }

    public func configure(with item: PreparedTextUIKitDemoItem) {
        cardView.configure(with: item)
    }

    private func configure() {
        backgroundColor = .clear
        contentView.addSubview(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}

public final class PreparedTextTableDemoViewController: UITableViewController, PreparedTextUIKitEmbeddablePage {
    private var items: [PreparedTextUIKitDemoItem]
    private let copy: PreparedTextUIKitCopy
    private var lastReportedEmbeddedHeight: CGFloat = 0

    public var embeddedContentHeightDidChange: ((CGFloat) -> Void)?

    public init(
        items: [PreparedTextUIKitDemoItem] = PreparedTextUIKitDemoItem.makeSamples(),
        language: PreparedTextDemoLanguage = .english
    ) {
        self.items = items
        copy = PreparedTextUIKitCopy(language: language)
        super.init(style: .insetGrouped)
    }

    public required init?(coder: NSCoder) {
        self.items = PreparedTextUIKitDemoItem.makeSamples()
        copy = PreparedTextUIKitCopy(language: .english)
        super.init(coder: coder)
    }

    public func apply(items: [PreparedTextUIKitDemoItem]) {
        self.items = items
        if isViewLoaded {
            tableView.reloadData()
            invalidateEmbeddedLayout()
        }
    }

    public func setEmbeddedScrollingEnabled(_ isEnabled: Bool) {
        tableView.isScrollEnabled = isEnabled
        tableView.alwaysBounceVertical = isEnabled
        tableView.showsVerticalScrollIndicator = isEnabled
        invalidateEmbeddedLayout()
    }

    public func invalidateEmbeddedLayout() {
        guard isViewLoaded else {
            return
        }
        tableView.setNeedsLayout()
        tableView.layoutIfNeeded()
        reportEmbeddedContentHeightIfNeeded(force: true)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = copy.tableScreenTitle
        tableView.register(PreparedTextTableViewCell.self, forCellReuseIdentifier: PreparedTextTableViewCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 156
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemGroupedBackground
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        reportEmbeddedContentHeightIfNeeded()
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        copy.selfSizingHeaderTitle
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PreparedTextTableViewCell.reuseIdentifier, for: indexPath)
        guard let preparedCell = cell as? PreparedTextTableViewCell else {
            return cell
        }
        preparedCell.configure(with: items[indexPath.row])
        return preparedCell
    }

    private func reportEmbeddedContentHeightIfNeeded(force: Bool = false) {
        guard let embeddedContentHeightDidChange else {
            return
        }

        let height = ceil(tableView.contentSize.height + tableView.adjustedContentInset.top + tableView.adjustedContentInset.bottom)
        guard height > 0 else {
            return
        }

        if force == false, abs(height - lastReportedEmbeddedHeight) < 0.5 {
            return
        }

        lastReportedEmbeddedHeight = height
        embeddedContentHeightDidChange(height)
    }
}

public final class PreparedTextCollectionDemoViewController: UICollectionViewController, PreparedTextUIKitEmbeddablePage {
    private var items: [PreparedTextUIKitDemoItem]
    private let copy: PreparedTextUIKitCopy
    private var lastReportedEmbeddedHeight: CGFloat = 0

    public var embeddedContentHeightDidChange: ((CGFloat) -> Void)?

    public init(
        items: [PreparedTextUIKitDemoItem] = PreparedTextUIKitDemoItem.makeSamples(),
        language: PreparedTextDemoLanguage = .english
    ) {
        self.items = items
        copy = PreparedTextUIKitCopy(language: language)
        super.init(collectionViewLayout: Self.makeLayout())
    }

    public required init?(coder: NSCoder) {
        self.items = PreparedTextUIKitDemoItem.makeSamples()
        copy = PreparedTextUIKitCopy(language: .english)
        super.init(coder: coder)
    }

    public func apply(items: [PreparedTextUIKitDemoItem]) {
        self.items = items
        if isViewLoaded {
            collectionView.reloadData()
            invalidateEmbeddedLayout()
        }
    }

    public func setEmbeddedScrollingEnabled(_ isEnabled: Bool) {
        collectionView.isScrollEnabled = isEnabled
        collectionView.alwaysBounceVertical = isEnabled
        collectionView.showsVerticalScrollIndicator = isEnabled
        invalidateEmbeddedLayout()
    }

    public func invalidateEmbeddedLayout() {
        guard isViewLoaded else {
            return
        }
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.setNeedsLayout()
        collectionView.layoutIfNeeded()
        reportEmbeddedContentHeightIfNeeded(force: true)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = copy.collectionScreenTitle
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.register(PreparedTextCollectionViewCell.self, forCellWithReuseIdentifier: PreparedTextCollectionViewCell.reuseIdentifier)
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        reportEmbeddedContentHeightIfNeeded()
    }

    public override func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PreparedTextCollectionViewCell.reuseIdentifier, for: indexPath)
        guard let preparedCell = cell as? PreparedTextCollectionViewCell else {
            return cell
        }
        preparedCell.configure(with: items[indexPath.item])
        return preparedCell
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(220)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(220)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 14
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 24, trailing: 16)

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        configuration.contentInsetsReference = .automatic

        return UICollectionViewCompositionalLayout(section: section, configuration: configuration)
    }

    private func reportEmbeddedContentHeightIfNeeded(force: Bool = false) {
        guard let embeddedContentHeightDidChange else {
            return
        }

        let contentHeight = collectionView.collectionViewLayout.collectionViewContentSize.height
        let height = ceil(contentHeight + collectionView.adjustedContentInset.top + collectionView.adjustedContentInset.bottom)
        guard height > 0 else {
            return
        }

        if force == false, abs(height - lastReportedEmbeddedHeight) < 0.5 {
            return
        }

        lastReportedEmbeddedHeight = height
        embeddedContentHeightDidChange(height)
    }
}

private final class PreparedTextDemoSurfaceCardView: UIView {
    private let chromeView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let modeBadge = PreparedPillLabel()
    private let badgeStack = UIStackView()
    private let noteLabel = UILabel()
    private let contentChromeView = UIView()
    private let verticalStack = UIStackView()
    private let headerStack = UIStackView()
    private let titleColumn = UIStackView()

    private let preparedLabelView = PreparedLabelView()
    private let measurementLabel = MeasurementCachingLabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func configure(with item: PreparedTextUIKitDemoItem) {
        chromeView.backgroundColor = .systemBackground
        contentChromeView.backgroundColor = item.surfaceColor
        contentChromeView.layer.borderColor = item.tintColor.withAlphaComponent(0.18).cgColor
        contentChromeView.layer.borderWidth = 1

        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        noteLabel.text = item.note

        modeBadge.text = item.surfaceMode.badgeTitle
        modeBadge.textColor = item.tintColor
        modeBadge.backgroundColor = item.tintColor.withAlphaComponent(0.12)

        rebuildBadges(using: item.capabilityTags, tintColor: item.tintColor)

        measurementLabel.attributedText = item.body
        measurementLabel.sourceID = item.sourceID
        measurementLabel.numberOfLines = item.numberOfLines
        measurementLabel.lineBreakMode = item.lineBreakMode
        measurementLabel.textAlignment = item.textAlignment

        preparedLabelView.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: item.body,
                sourceID: item.sourceID,
                whiteSpaceMode: item.whiteSpaceMode,
                numberOfLines: item.numberOfLines,
                lineBreakMode: item.lineBreakMode,
                textAlignment: item.textAlignment,
                automaticallyOpensLinks: false
            )
        )

        measurementLabel.isHidden = item.surfaceMode != .stage0MeasureOnly
        preparedLabelView.isHidden = item.surfaceMode != .stage1Prepared
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        chromeView.translatesAutoresizingMaskIntoConstraints = false
        chromeView.layer.cornerRadius = 24
        chromeView.layer.cornerCurve = .continuous

        contentChromeView.translatesAutoresizingMaskIntoConstraints = false
        contentChromeView.layer.cornerRadius = 20
        contentChromeView.layer.cornerCurve = .continuous

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        noteLabel.font = .preferredFont(forTextStyle: .footnote)
        noteLabel.adjustsFontForContentSizeCategory = true
        noteLabel.textColor = .secondaryLabel
        noteLabel.numberOfLines = 0

        modeBadge.font = .preferredFont(forTextStyle: .caption1)

        badgeStack.axis = .horizontal
        badgeStack.spacing = 8
        badgeStack.alignment = .leading

        verticalStack.axis = .vertical
        verticalStack.spacing = 12
        verticalStack.translatesAutoresizingMaskIntoConstraints = false

        headerStack.axis = .horizontal
        headerStack.alignment = .top
        headerStack.spacing = 12

        titleColumn.axis = .vertical
        titleColumn.spacing = 4
        titleColumn.addArrangedSubview(titleLabel)
        titleColumn.addArrangedSubview(subtitleLabel)

        headerStack.addArrangedSubview(titleColumn)
        headerStack.addArrangedSubview(modeBadge)

        measurementLabel.numberOfLines = 0
        measurementLabel.translatesAutoresizingMaskIntoConstraints = false
        preparedLabelView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(chromeView)
        chromeView.addSubview(verticalStack)
        verticalStack.addArrangedSubview(headerStack)
        verticalStack.addArrangedSubview(badgeStack)
        verticalStack.addArrangedSubview(contentChromeView)
        verticalStack.addArrangedSubview(noteLabel)

        contentChromeView.addSubview(measurementLabel)
        contentChromeView.addSubview(preparedLabelView)

        NSLayoutConstraint.activate([
            chromeView.topAnchor.constraint(equalTo: topAnchor),
            chromeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chromeView.trailingAnchor.constraint(equalTo: trailingAnchor),
            chromeView.bottomAnchor.constraint(equalTo: bottomAnchor),

            verticalStack.topAnchor.constraint(equalTo: chromeView.topAnchor, constant: 18),
            verticalStack.leadingAnchor.constraint(equalTo: chromeView.leadingAnchor, constant: 18),
            verticalStack.trailingAnchor.constraint(equalTo: chromeView.trailingAnchor, constant: -18),
            verticalStack.bottomAnchor.constraint(equalTo: chromeView.bottomAnchor, constant: -18),

            measurementLabel.topAnchor.constraint(equalTo: contentChromeView.topAnchor, constant: 16),
            measurementLabel.leadingAnchor.constraint(equalTo: contentChromeView.leadingAnchor, constant: 16),
            measurementLabel.trailingAnchor.constraint(equalTo: contentChromeView.trailingAnchor, constant: -16),
            measurementLabel.bottomAnchor.constraint(equalTo: contentChromeView.bottomAnchor, constant: -16),

            preparedLabelView.topAnchor.constraint(equalTo: contentChromeView.topAnchor, constant: 16),
            preparedLabelView.leadingAnchor.constraint(equalTo: contentChromeView.leadingAnchor, constant: 16),
            preparedLabelView.trailingAnchor.constraint(equalTo: contentChromeView.trailingAnchor, constant: -16),
            preparedLabelView.bottomAnchor.constraint(equalTo: contentChromeView.bottomAnchor, constant: -16),
        ])
    }

    private func rebuildBadges(using tags: [String], tintColor: UIColor) {
        badgeStack.arrangedSubviews.forEach { view in
            badgeStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for tag in tags {
            let badge = PreparedPillLabel()
            badge.text = tag
            badge.font = .preferredFont(forTextStyle: .caption1)
            badge.textColor = tintColor
            badge.backgroundColor = tintColor.withAlphaComponent(0.12)
            badge.layer.cornerRadius = 12
            badge.layer.cornerCurve = .continuous
            badgeStack.addArrangedSubview(badge)
        }
    }
}

private struct PreparedTextUIKitCopy {
    let overviewScreenTitle: String
    let tableScreenTitle: String
    let collectionScreenTitle: String
    let selfSizingHeaderTitle: String
    let heroTitle: String
    let heroDetail: String
    let heroChipRolloutTitle: String
    let heroChipRolloutValue: String
    let heroChipSurfaceTitle: String
    let heroChipSurfaceValue: String
    let heroChipContractTitle: String
    let heroChipContractValue: String
    let rolloutEyebrow: String
    let rolloutTitle: String
    let rolloutDetail: String
    let stage0Label: String
    let stage1Label: String
    let previewHeightLabel: String
    let rolloutPreviewTitle: String
    let rolloutPreviewBody: String
    let stage0Description: String
    let stage1Description: String
    let rendererEyebrow: String
    let rendererTitle: String
    let rendererDetail: String
    let rendererPreviewBody: String
    let migrationGuideLinkText: String
    let rendererStatusIdle: String
    let rendererStatusTappedPrefix: String
    let whitespaceEyebrow: String
    let whitespacePanelTitle: String
    let whitespacePanelDetail: String
    let whitespaceLiteralTitle: String
    let whitespaceLiteralDetail: String
    let whitespaceCSSNormalTitle: String
    let whitespaceCSSNormalDetail: String
    let whitespacePreWrapTitle: String
    let whitespacePreWrapDetail: String
    let whitespaceBody: String
    let stage0RolloutTitle: String
    let stage0RolloutSubtitle: String
    let stage0RolloutNote: String
    let stage0RolloutBody: String
    let stage1BubbleTitle: String
    let stage1BubbleSubtitle: String
    let stage1BubbleNote: String
    let stage1BubbleBody: String
    let releaseGuideLinkText: String
    let feedCardTitle: String
    let feedCardSubtitle: String
    let feedCardNote: String
    let feedSummaryTitle: String
    let feedSummaryBody: String
    let stage0ListTitle: String
    let stage0ListSubtitle: String
    let stage0ListNote: String
    let stage0ListBody: String
    let whitespaceTitle: String
    let whitespaceSubtitle: String
    let whitespaceNote: String
    let centeredCalloutTitle: String
    let centeredCalloutSubtitle: String
    let centeredCalloutNote: String
    let centeredCalloutBody: String

    init(language: PreparedTextDemoLanguage) {
        switch language {
        case .english:
            overviewScreenTitle = "UIKit Overview"
            tableScreenTitle = "UITableView"
            collectionScreenTitle = "UICollectionView"
            selfSizingHeaderTitle = "Self-sizing surfaces"
            heroTitle = "UIKit should explain rollout, not just show rows."
            heroDetail = "Use this screen to show the safer stage-0 measurement path, the richer stage-1 renderer path, and the narrow read-only contract that keeps the scope honest."
            heroChipRolloutTitle = "Rollout"
            heroChipRolloutValue = "Stage 0 -> 1"
            heroChipSurfaceTitle = "Surface"
            heroChipSurfaceValue = "Read-only"
            heroChipContractTitle = "Contract"
            heroChipContractValue = "UIKit literal"
            rolloutEyebrow = "Rollout lab"
            rolloutTitle = "Switch between Stage 0 and Stage 1 on the same payload"
            rolloutDetail = "The same text should make the adoption story obvious: stage 0 keeps UILabel as renderer, stage 1 owns layout and draw inside PreparedLabelView."
            stage0Label = "Stage 0"
            stage1Label = "Stage 1"
            previewHeightLabel = "Preview height"
            rolloutPreviewTitle = "Prepared rollout note"
            rolloutPreviewBody = "Use the same immutable payload while the width changes. Stage 0 keeps UILabel in charge. Stage 1 lets PreparedLabelView own layout and draw."
            stage0Description = "Stage 0 keeps UILabel as the renderer and only accelerates sizing. This is the lower-risk adoption path."
            stage1Description = "Stage 1 lets PreparedLabelView own layout and draw while still staying in a narrow read-only surface."
            rendererEyebrow = "Renderer surface"
            rendererTitle = "Show stage-1 behaviors that are hard to fake with plain screenshots"
            rendererDetail = "Center alignment, line limits, and link interaction should all be visible in one place so the UIKit screen reads like a capability lab."
            rendererPreviewBody = "Tap the migration guide to confirm that the SwiftUI bridge and the UIKit surface are still using the same prepared link path."
            migrationGuideLinkText = "migration guide"
            rendererStatusIdle = "Tap the highlighted guide inside the preview."
            rendererStatusTappedPrefix = "Tapped"
            whitespaceEyebrow = "Text contract"
            whitespacePanelTitle = "Make whitespace behavior explicit in UIKit too"
            whitespacePanelDetail = "This is where people should immediately notice the difference between UIKit literal, CSS-like collapse, and opt-in pre-wrap."
            whitespaceLiteralTitle = "UIKit literal"
            whitespaceLiteralDetail = "Default mode. Explicit newlines, repeated spaces, and tabs stay literal."
            whitespaceCSSNormalTitle = "CSS normal"
            whitespaceCSSNormalDetail = "Collapse semantics are opt-in when a screen genuinely wants web-style whitespace."
            whitespacePreWrapTitle = "pre-wrap"
            whitespacePreWrapDetail = "Preserve authored spacing for code-like or debug-oriented copy."
            whitespaceBody = "Status:\nReady    for\treview"
            stage0RolloutTitle = "Stage 0 Rollout Path"
            stage0RolloutSubtitle = "UILabel render, cached measurement"
            stage0RolloutNote = "This is the safer first step when a product team only wants self-sizing wins."
            stage0RolloutBody = "Keep UILabel as the rendering authority, cache sizing, and watch self-sizing churn calm down before introducing the prepared renderer."
            stage1BubbleTitle = "Stage 1 Chat Bubble"
            stage1BubbleSubtitle = "Prepared draw with link-aware text"
            stage1BubbleNote = "The demo keeps link styling visible here; interactive link handling is highlighted in the UIKit overview screen."
            stage1BubbleBody = "Tap-safe link handling inside a bubble still belongs to the prepared read-only renderer. Review the release guide for the full contract."
            releaseGuideLinkText = "release guide"
            feedCardTitle = "Feed Summary Card"
            feedCardSubtitle = "Tail truncation and stable summary height"
            feedCardNote = "This is the product-shaped example: a card that wants consistent height without pretending to replace UILabel everywhere."
            feedSummaryTitle = "Prepared feed summary"
            feedSummaryBody = "Stage 1 should keep a predictable card height even when the visible width tightens or line limits clamp the summary."
            stage0ListTitle = "Stage 0 List Detail"
            stage0ListSubtitle = "Lower-risk path for reused cells"
            stage0ListNote = "If a screen already trusts UILabel visually, stage 0 is the least disruptive place to start."
            stage0ListBody = "Measurement caching is the low-risk rollout path for existing table and collection surfaces that already depend on UILabel behavior."
            whitespaceTitle = "Whitespace Contract"
            whitespaceSubtitle = "Opt-in pre-wrap, not a hidden default"
            whitespaceNote = "Use this when authored spaces and tabs matter. The demo should make that contract legible."
            centeredCalloutTitle = "Centered Status Callout"
            centeredCalloutSubtitle = "Compact alignment and middle truncation"
            centeredCalloutNote = "Center alignment and tight line limits are easier to trust when the demo shows them in a realistic status surface."
            centeredCalloutBody = "PreparedLabelView stays narrow on purpose: line limits, alignment, truncation, and links for read-only product copy."
        case .korean:
            overviewScreenTitle = "UIKit 개요"
            tableScreenTitle = "UITableView"
            collectionScreenTitle = "UICollectionView"
            selfSizingHeaderTitle = "Self-sizing 서피스"
            heroTitle = "UIKit은 단순한 샘플이 아니라 도입 경로를 설명해야 합니다."
            heroDetail = "이 화면은 더 안전한 Stage 0 측정 경로, 더 풍부한 Stage 1 렌더러 경로, 그리고 정직한 read-only 계약을 한 번에 보여주기 위한 화면입니다."
            heroChipRolloutTitle = "도입"
            heroChipRolloutValue = "Stage 0 -> 1"
            heroChipSurfaceTitle = "서피스"
            heroChipSurfaceValue = "읽기 전용"
            heroChipContractTitle = "계약"
            heroChipContractValue = "UIKit literal"
            rolloutEyebrow = "도입 실험실"
            rolloutTitle = "같은 payload에서 Stage 0와 Stage 1을 전환해보기"
            rolloutDetail = "같은 텍스트로 Stage 0는 UILabel 렌더링을 유지하고, Stage 1은 PreparedLabelView가 layout과 draw를 맡는 차이를 보여줘야 합니다."
            stage0Label = "Stage 0"
            stage1Label = "Stage 1"
            previewHeightLabel = "미리보기 높이"
            rolloutPreviewTitle = "Prepared 도입 메모"
            rolloutPreviewBody = "너비가 바뀌어도 같은 immutable payload를 유지합니다. Stage 0는 UILabel이 렌더링을 맡고, Stage 1은 PreparedLabelView가 layout과 draw를 담당합니다."
            stage0Description = "Stage 0는 UILabel을 렌더링 권한으로 유지하고 sizing만 가속합니다. 가장 안전한 도입 경로입니다."
            stage1Description = "Stage 1은 PreparedLabelView가 layout과 draw를 맡지만, 여전히 좁은 read-only surface에 머뭅니다."
            rendererEyebrow = "렌더러 서피스"
            rendererTitle = "정적인 스크린샷만으로는 확인하기 어려운 Stage 1 동작 보여주기"
            rendererDetail = "가운데 정렬, 줄 수 제한, 링크 상호작용이 한곳에 보여야 UIKit 화면이 실제 capability lab처럼 느껴집니다."
            rendererPreviewBody = "migration guide를 눌러서 SwiftUI 브리지와 UIKit surface가 같은 prepared link 경로를 쓰는지 확인해보세요."
            migrationGuideLinkText = "migration guide"
            rendererStatusIdle = "미리보기 안의 강조된 가이드를 눌러보세요."
            rendererStatusTappedPrefix = "탭함"
            whitespaceEyebrow = "텍스트 계약"
            whitespacePanelTitle = "UIKit에서도 whitespace 동작을 명확하게 보여주기"
            whitespacePanelDetail = "여기서는 UIKit literal, CSS-like collapse, opt-in pre-wrap의 차이가 즉시 보여야 합니다."
            whitespaceLiteralTitle = "UIKit literal"
            whitespaceLiteralDetail = "기본 모드입니다. 줄바꿈, 반복 공백, 탭을 그대로 유지합니다."
            whitespaceCSSNormalTitle = "CSS normal"
            whitespaceCSSNormalDetail = "웹 스타일 whitespace가 정말 필요한 화면에서만 opt-in으로 사용합니다."
            whitespacePreWrapTitle = "pre-wrap"
            whitespacePreWrapDetail = "코드나 디버그용 텍스트처럼 작성된 간격을 그대로 유지합니다."
            whitespaceBody = "상태:\n리뷰\t준비    완료"
            stage0RolloutTitle = "Stage 0 도입 경로"
            stage0RolloutSubtitle = "UILabel 렌더링, 측정 캐시"
            stage0RolloutNote = "제품 팀이 self-sizing 개선만 원할 때 가장 안전한 첫 단계입니다."
            stage0RolloutBody = "UILabel을 렌더링 권한으로 유지하고 sizing을 캐시해서, prepared renderer를 넣기 전 self-sizing churn이 가라앉는지 먼저 확인합니다."
            stage1BubbleTitle = "Stage 1 채팅 버블"
            stage1BubbleSubtitle = "링크 인식 텍스트를 prepared draw로 렌더링"
            stage1BubbleNote = "여기서는 링크 스타일을 그대로 보여주고, 실제 링크 상호작용은 UIKit overview 화면에서 강조합니다."
            stage1BubbleBody = "버블 안의 안전한 링크 처리도 prepared read-only renderer 경로에 속합니다. 전체 계약은 release guide에서 확인하세요."
            releaseGuideLinkText = "release guide"
            feedCardTitle = "피드 요약 카드"
            feedCardSubtitle = "tail truncation과 안정적인 요약 높이"
            feedCardNote = "이건 제품형 예시입니다. 어디서나 UILabel을 대체하려는 척하지 않고도 카드 높이를 일정하게 유지하려는 surface입니다."
            feedSummaryTitle = "Prepared 피드 요약"
            feedSummaryBody = "Stage 1은 보이는 너비가 좁아지거나 줄 수 제한이 걸려도 예측 가능한 카드 높이를 유지해야 합니다."
            stage0ListTitle = "Stage 0 리스트 상세"
            stage0ListSubtitle = "재사용 셀에 더 안전한 경로"
            stage0ListNote = "이미 UILabel의 시각 결과를 신뢰하는 화면이라면, Stage 0가 가장 덜 파괴적인 출발점입니다."
            stage0ListBody = "Measurement caching은 이미 UILabel 동작에 의존하는 table/collection surface에 가장 저위험으로 도입할 수 있는 경로입니다."
            whitespaceTitle = "Whitespace 계약"
            whitespaceSubtitle = "숨겨진 기본값이 아닌 opt-in pre-wrap"
            whitespaceNote = "작성된 공백과 탭이 중요할 때 쓰는 모드라는 점이 데모에서 분명해야 합니다."
            centeredCalloutTitle = "가운데 정렬 상태 콜아웃"
            centeredCalloutSubtitle = "컴팩트 정렬과 middle truncation"
            centeredCalloutNote = "가운데 정렬과 촘촘한 줄 수 제한은 실제 상태 surface에서 보여줄 때 더 신뢰하기 쉽습니다."
            centeredCalloutBody = "PreparedLabelView는 의도적으로 좁은 surface를 유지합니다. read-only 제품 카피를 위한 줄 수 제한, 정렬, truncation, 링크에 집중합니다."
        case .japanese:
            overviewScreenTitle = "UIKit 概要"
            tableScreenTitle = "UITableView"
            collectionScreenTitle = "UICollectionView"
            selfSizingHeaderTitle = "Self-sizing サーフェス"
            heroTitle = "UIKit は行を見せるだけでなく、導入経路を説明できるべきです。"
            heroDetail = "この画面では、より安全な Stage 0 の計測経路、より豊かな Stage 1 のレンダラー経路、そして正直な read-only 契約を一度に確認できます。"
            heroChipRolloutTitle = "導入"
            heroChipRolloutValue = "Stage 0 -> 1"
            heroChipSurfaceTitle = "サーフェス"
            heroChipSurfaceValue = "読み取り専用"
            heroChipContractTitle = "契約"
            heroChipContractValue = "UIKit literal"
            rolloutEyebrow = "導入ラボ"
            rolloutTitle = "同じ payload で Stage 0 と Stage 1 を切り替える"
            rolloutDetail = "同じテキストで、Stage 0 は UILabel に描画を任せ、Stage 1 は PreparedLabelView が layout と draw を担当する違いを示します。"
            stage0Label = "Stage 0"
            stage1Label = "Stage 1"
            previewHeightLabel = "プレビュー高さ"
            rolloutPreviewTitle = "Prepared 導入メモ"
            rolloutPreviewBody = "幅が変わっても同じ immutable payload を使います。Stage 0 は UILabel が描画を担当し、Stage 1 は PreparedLabelView が layout と draw を担当します。"
            stage0Description = "Stage 0 は UILabel を描画権限として残し、sizing だけを高速化します。最も低リスクな導入経路です。"
            stage1Description = "Stage 1 は PreparedLabelView が layout と draw を担当しますが、read-only の狭い surface に留まります。"
            rendererEyebrow = "レンダラーサーフェス"
            rendererTitle = "静止画だけでは分かりにくい Stage 1 の挙動を見せる"
            rendererDetail = "中央揃え、行数制限、リンク操作を一か所で見せることで、この UIKit 画面が capability lab として読めるようにします。"
            rendererPreviewBody = "migration guide をタップして、SwiftUI bridge と UIKit surface が同じ prepared link 経路を使っていることを確認してください。"
            migrationGuideLinkText = "migration guide"
            rendererStatusIdle = "プレビュー内の強調されたガイドをタップしてください。"
            rendererStatusTappedPrefix = "タップ済み"
            whitespaceEyebrow = "テキスト契約"
            whitespacePanelTitle = "UIKit でも whitespace の挙動を明示する"
            whitespacePanelDetail = "ここでは UIKit literal、CSS-like collapse、opt-in pre-wrap の違いがすぐに分かる必要があります。"
            whitespaceLiteralTitle = "UIKit literal"
            whitespaceLiteralDetail = "既定モードです。改行、連続スペース、タブをそのまま保持します。"
            whitespaceCSSNormalTitle = "CSS normal"
            whitespaceCSSNormalDetail = "Web 風の whitespace が本当に必要な画面でのみ opt-in します。"
            whitespacePreWrapTitle = "pre-wrap"
            whitespacePreWrapDetail = "コードやデバッグ向けテキストのように、書かれた間隔をそのまま保持します。"
            whitespaceBody = "状態:\nレビュー\t準備    完了"
            stage0RolloutTitle = "Stage 0 導入経路"
            stage0RolloutSubtitle = "UILabel 描画、計測キャッシュ"
            stage0RolloutNote = "プロダクトチームが self-sizing の改善だけを求める場合の最も安全な最初の一歩です。"
            stage0RolloutBody = "UILabel を描画権限として維持し、sizing をキャッシュして、prepared renderer を導入する前に self-sizing churn が落ち着くかを確認します。"
            stage1BubbleTitle = "Stage 1 チャットバブル"
            stage1BubbleSubtitle = "リンクを含むテキストを prepared draw で描画"
            stage1BubbleNote = "ここではリンクの見た目を維持し、実際のリンク操作は UIKit overview 画面で強調します。"
            stage1BubbleBody = "バブル内の安全なリンク処理も prepared read-only renderer の責務です。全体の契約は release guide を確認してください。"
            releaseGuideLinkText = "release guide"
            feedCardTitle = "フィード要約カード"
            feedCardSubtitle = "tail truncation と安定した要約高さ"
            feedCardNote = "これは実製品に近い例です。どこでも UILabel を置き換えるふりをせずに、カードの高さを一定に保つ surface です。"
            feedSummaryTitle = "Prepared フィード要約"
            feedSummaryBody = "Stage 1 は、見える幅が狭くなっても、また行数制限で要約が抑えられても、予測可能なカード高さを保つべきです。"
            stage0ListTitle = "Stage 0 リスト詳細"
            stage0ListSubtitle = "再利用セル向けの低リスク経路"
            stage0ListNote = "すでに UILabel の見た目を信頼している画面では、Stage 0 が最も破壊的でない出発点です。"
            stage0ListBody = "Measurement caching は、すでに UILabel の挙動に依存している table / collection surface に最も低リスクで導入できる経路です。"
            whitespaceTitle = "Whitespace 契約"
            whitespaceSubtitle = "隠れた既定値ではなく opt-in pre-wrap"
            whitespaceNote = "書かれたスペースやタブが重要なときに使うモードであることが、デモからすぐ分かる必要があります。"
            centeredCalloutTitle = "中央揃えステータスコールアウト"
            centeredCalloutSubtitle = "コンパクトな整列と middle truncation"
            centeredCalloutNote = "中央揃えと厳しい行数制限は、実際のステータス surface で示した方が信頼しやすくなります。"
            centeredCalloutBody = "PreparedLabelView は意図的に狭い surface に留まります。read-only な製品コピー向けに、行数制限、整列、truncation、リンクに集中します。"
        case .chineseSimplified:
            overviewScreenTitle = "UIKit 概览"
            tableScreenTitle = "UITableView"
            collectionScreenTitle = "UICollectionView"
            selfSizingHeaderTitle = "自适应高度界面"
            heroTitle = "UIKit 不该只展示几行文本，还要把接入路径讲清楚。"
            heroDetail = "这个页面会同时展示更稳妥的 Stage 0 测量路径、更完整的 Stage 1 渲染路径，以及保持诚实范围的 read-only 契约。"
            heroChipRolloutTitle = "接入"
            heroChipRolloutValue = "Stage 0 -> 1"
            heroChipSurfaceTitle = "界面"
            heroChipSurfaceValue = "只读"
            heroChipContractTitle = "契约"
            heroChipContractValue = "UIKit literal"
            rolloutEyebrow = "接入实验室"
            rolloutTitle = "在同一份 payload 上切换 Stage 0 和 Stage 1"
            rolloutDetail = "用同一段文本直接说明差异：Stage 0 继续由 UILabel 渲染，Stage 1 则由 PreparedLabelView 接管 layout 和 draw。"
            stage0Label = "Stage 0"
            stage1Label = "Stage 1"
            previewHeightLabel = "预览高度"
            rolloutPreviewTitle = "Prepared 接入说明"
            rolloutPreviewBody = "宽度变化时仍然复用同一份 immutable payload。Stage 0 保持 UILabel 渲染，Stage 1 由 PreparedLabelView 负责 layout 和 draw。"
            stage0Description = "Stage 0 保留 UILabel 作为渲染权威，只加速 sizing。这是风险最低的接入路径。"
            stage1Description = "Stage 1 让 PreparedLabelView 接管 layout 和 draw，但仍然保持在狭窄的 read-only surface 内。"
            rendererEyebrow = "渲染器界面"
            rendererTitle = "把静态截图难以说明的 Stage 1 行为直接展示出来"
            rendererDetail = "居中对齐、行数限制和链接交互应该在一个区域内同时可见，这样 UIKit 页面才像真正的 capability lab。"
            rendererPreviewBody = "点击 migration guide，确认 SwiftUI bridge 和 UIKit surface 仍然共用同一条 prepared link 路径。"
            migrationGuideLinkText = "migration guide"
            rendererStatusIdle = "点击预览中高亮的指南链接。"
            rendererStatusTappedPrefix = "已点击"
            whitespaceEyebrow = "文本契约"
            whitespacePanelTitle = "在 UIKit 中也把 whitespace 行为说清楚"
            whitespacePanelDetail = "在这里应该一眼看出 UIKit literal、CSS-like collapse 和 opt-in pre-wrap 的区别。"
            whitespaceLiteralTitle = "UIKit literal"
            whitespaceLiteralDetail = "默认模式。显式换行、连续空格和制表符都会原样保留。"
            whitespaceCSSNormalTitle = "CSS normal"
            whitespaceCSSNormalDetail = "只有确实需要 Web 风格空白折叠的界面才应 opt-in。"
            whitespacePreWrapTitle = "pre-wrap"
            whitespacePreWrapDetail = "适合代码或调试文本，保留原始书写间距。"
            whitespaceBody = "状态:\n准备\t进行    审查"
            stage0RolloutTitle = "Stage 0 接入路径"
            stage0RolloutSubtitle = "UILabel 渲染，测量缓存"
            stage0RolloutNote = "当产品团队只想先获得 self-sizing 收益时，这是更稳妥的第一步。"
            stage0RolloutBody = "继续让 UILabel 作为渲染权威，只缓存 sizing，先观察 self-sizing 抖动是否下降，再决定是否引入 prepared renderer。"
            stage1BubbleTitle = "Stage 1 聊天氣泡"
            stage1BubbleSubtitle = "用 prepared draw 渲染可识别链接的文本"
            stage1BubbleNote = "这里保留链接样式，真正的链接交互会在 UIKit overview 页面里重点展示。"
            stage1BubbleBody = "气泡里的安全链接处理仍然属于 prepared read-only renderer 的职责。完整契约请查看 release guide。"
            releaseGuideLinkText = "release guide"
            feedCardTitle = "信息流摘要卡片"
            feedCardSubtitle = "尾部截断与稳定摘要高度"
            feedCardNote = "这是更贴近产品的例子：它追求稳定卡片高度，但并不假装要在所有地方替代 UILabel。"
            feedSummaryTitle = "Prepared 信息流摘要"
            feedSummaryBody = "Stage 1 应该在可见宽度变窄或行数限制生效时，仍然保持可预测的卡片高度。"
            stage0ListTitle = "Stage 0 列表详情"
            stage0ListSubtitle = "复用单元格的低风险路径"
            stage0ListNote = "如果某个界面已经信任 UILabel 的视觉结果，Stage 0 是破坏性最小的起点。"
            stage0ListBody = "Measurement caching 是现有 table / collection 界面中最适合低风险接入的路径，尤其是这些界面已经依赖 UILabel 行为时。"
            whitespaceTitle = "Whitespace 契约"
            whitespaceSubtitle = "不是隐藏默认值，而是明确 opt-in 的 pre-wrap"
            whitespaceNote = "当书写时的空格和制表符很重要时，demo 应该把这个契约直接展示出来。"
            centeredCalloutTitle = "居中状态提示"
            centeredCalloutSubtitle = "紧凑对齐与 middle truncation"
            centeredCalloutNote = "居中对齐和严格行数限制，放在真实状态界面里展示会更容易被信任。"
            centeredCalloutBody = "PreparedLabelView 有意保持窄范围：面向 read-only 产品文案，只支持行数限制、对齐、truncation 和链接。"
        case .chineseTraditional:
            overviewScreenTitle = "UIKit 概覽"
            tableScreenTitle = "UITableView"
            collectionScreenTitle = "UICollectionView"
            selfSizingHeaderTitle = "自適應高度介面"
            heroTitle = "UIKit 不該只展示幾行文字，還要把導入路徑說清楚。"
            heroDetail = "這個頁面會同時展示更穩妥的 Stage 0 測量路徑、更完整的 Stage 1 渲染路徑，以及保持誠實範圍的 read-only 契約。"
            heroChipRolloutTitle = "導入"
            heroChipRolloutValue = "Stage 0 -> 1"
            heroChipSurfaceTitle = "介面"
            heroChipSurfaceValue = "唯讀"
            heroChipContractTitle = "契約"
            heroChipContractValue = "UIKit literal"
            rolloutEyebrow = "導入實驗室"
            rolloutTitle = "在同一份 payload 上切換 Stage 0 和 Stage 1"
            rolloutDetail = "用同一段文字直接說明差異：Stage 0 繼續由 UILabel 渲染，Stage 1 則由 PreparedLabelView 接手 layout 和 draw。"
            stage0Label = "Stage 0"
            stage1Label = "Stage 1"
            previewHeightLabel = "預覽高度"
            rolloutPreviewTitle = "Prepared 導入說明"
            rolloutPreviewBody = "寬度改變時仍然重用同一份 immutable payload。Stage 0 維持 UILabel 渲染，Stage 1 則由 PreparedLabelView 負責 layout 和 draw。"
            stage0Description = "Stage 0 保留 UILabel 作為渲染權威，只加速 sizing。這是風險最低的導入路徑。"
            stage1Description = "Stage 1 讓 PreparedLabelView 接手 layout 和 draw，但仍然維持在狹窄的 read-only surface 內。"
            rendererEyebrow = "渲染器介面"
            rendererTitle = "把靜態截圖難以說明的 Stage 1 行為直接展示出來"
            rendererDetail = "置中對齊、行數限制與連結互動應該在同一區域內同時可見，這樣 UIKit 頁面才像真正的 capability lab。"
            rendererPreviewBody = "點擊 migration guide，確認 SwiftUI bridge 與 UIKit surface 仍然共用同一條 prepared link 路徑。"
            migrationGuideLinkText = "migration guide"
            rendererStatusIdle = "點擊預覽中高亮的指南連結。"
            rendererStatusTappedPrefix = "已點擊"
            whitespaceEyebrow = "文字契約"
            whitespacePanelTitle = "在 UIKit 中也把 whitespace 行為說清楚"
            whitespacePanelDetail = "在這裡應該一眼看出 UIKit literal、CSS-like collapse 與 opt-in pre-wrap 的差異。"
            whitespaceLiteralTitle = "UIKit literal"
            whitespaceLiteralDetail = "預設模式。顯式換行、連續空格與 tab 都會原樣保留。"
            whitespaceCSSNormalTitle = "CSS normal"
            whitespaceCSSNormalDetail = "只有真的需要 Web 風格空白折疊的介面才應該 opt-in。"
            whitespacePreWrapTitle = "pre-wrap"
            whitespacePreWrapDetail = "適合程式碼或除錯文字，保留原始書寫間距。"
            whitespaceBody = "狀態:\n準備\t進行    審查"
            stage0RolloutTitle = "Stage 0 導入路徑"
            stage0RolloutSubtitle = "UILabel 渲染，測量快取"
            stage0RolloutNote = "當產品團隊只想先拿到 self-sizing 收益時，這是更穩妥的第一步。"
            stage0RolloutBody = "繼續讓 UILabel 作為渲染權威，只快取 sizing，先觀察 self-sizing 抖動是否下降，再決定是否導入 prepared renderer。"
            stage1BubbleTitle = "Stage 1 聊天气泡"
            stage1BubbleSubtitle = "用 prepared draw 渲染可辨識連結的文字"
            stage1BubbleNote = "這裡保留連結樣式，真正的連結互動會在 UIKit overview 頁面中重點展示。"
            stage1BubbleBody = "氣泡中的安全連結處理仍然屬於 prepared read-only renderer 的職責。完整契約請查看 release guide。"
            releaseGuideLinkText = "release guide"
            feedCardTitle = "資訊流摘要卡片"
            feedCardSubtitle = "尾端截斷與穩定摘要高度"
            feedCardNote = "這是更貼近產品的例子：它追求穩定卡片高度，但並不假裝要在所有地方取代 UILabel。"
            feedSummaryTitle = "Prepared 資訊流摘要"
            feedSummaryBody = "Stage 1 應該在可見寬度變窄或行數限制生效時，仍然維持可預測的卡片高度。"
            stage0ListTitle = "Stage 0 清單細節"
            stage0ListSubtitle = "重用 cell 的低風險路徑"
            stage0ListNote = "如果某個介面已經信任 UILabel 的視覺結果，Stage 0 是破壞性最小的起點。"
            stage0ListBody = "Measurement caching 是現有 table / collection 介面中最適合低風險導入的路徑，尤其是這些介面已經依賴 UILabel 行為時。"
            whitespaceTitle = "Whitespace 契約"
            whitespaceSubtitle = "不是隱藏預設值，而是明確 opt-in 的 pre-wrap"
            whitespaceNote = "當書寫時的空格與 tab 很重要時，demo 應該把這個契約直接展示出來。"
            centeredCalloutTitle = "置中狀態提示"
            centeredCalloutSubtitle = "緊湊對齊與 middle truncation"
            centeredCalloutNote = "置中對齊與嚴格行數限制，放在真實狀態介面中展示會更容易被信任。"
            centeredCalloutBody = "PreparedLabelView 有意維持狹窄範圍：面向 read-only 產品文案，只支援行數限制、對齊、truncation 與連結。"
        }
    }
}

private final class PreparedWhitespaceModeRowView: UIView {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let previewChromeView = UIView()
    private let previewLabel = PreparedLabelView()
    private let verticalStack = UIStackView()

    init(title: String, detail: String, mode: WhiteSpaceMode, tintColor: UIColor, text: NSAttributedString, sourceID: PreparedTextSourceID) {
        super.init(frame: .zero)
        configure()

        titleLabel.text = title
        detailLabel.text = detail
        previewChromeView.backgroundColor = tintColor.withAlphaComponent(0.10)

        previewLabel.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: text,
                sourceID: sourceID,
                whiteSpaceMode: mode,
                lineBreakMode: .byWordWrapping,
                automaticallyOpensLinks: false
            )
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        verticalStack.axis = .vertical
        verticalStack.spacing = 10
        verticalStack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0

        previewChromeView.translatesAutoresizingMaskIntoConstraints = false
        previewChromeView.layer.cornerRadius = 16
        previewChromeView.layer.cornerCurve = .continuous

        previewLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(verticalStack)
        verticalStack.addArrangedSubview(titleLabel)
        verticalStack.addArrangedSubview(detailLabel)
        verticalStack.addArrangedSubview(previewChromeView)
        previewChromeView.addSubview(previewLabel)

        NSLayoutConstraint.activate([
            verticalStack.topAnchor.constraint(equalTo: topAnchor),
            verticalStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            verticalStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            verticalStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            previewLabel.topAnchor.constraint(equalTo: previewChromeView.topAnchor, constant: 14),
            previewLabel.leadingAnchor.constraint(equalTo: previewChromeView.leadingAnchor, constant: 14),
            previewLabel.trailingAnchor.constraint(equalTo: previewChromeView.trailingAnchor, constant: -14),
            previewLabel.bottomAnchor.constraint(equalTo: previewChromeView.bottomAnchor, constant: -14),
        ])
    }
}

private final class PreparedDemoPanelView: UIView {
    let contentStack = UIStackView()

    init(eyebrow: String, title: String, detail: String) {
        super.init(frame: .zero)
        configureBase()

        let eyebrowLabel = UILabel()
        eyebrowLabel.font = .systemFont(ofSize: 11, weight: .bold)
        eyebrowLabel.textColor = .secondaryLabel
        eyebrowLabel.text = eyebrow.uppercased()

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.text = title

        let detailLabel = UILabel()
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.text = detail

        contentStack.addArrangedSubview(eyebrowLabel)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(detailLabel)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureBase()
    }

    private func configureBase() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .systemBackground
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])
    }
}

private final class PreparedPillLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(width: base.width + 18, height: base.height + 10)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 9, dy: 5))
    }
}

private extension PreparedTextSurfaceMode {
    var badgeTitle: String {
        switch self {
        case .stage0MeasureOnly:
            return "Stage 0"
        case .stage1Prepared:
            return "Stage 1"
        }
    }
}

private extension NSMutableAttributedString {
    func thenAppending(_ attributedText: NSAttributedString) -> NSAttributedString {
        append(attributedText)
        return copy() as? NSAttributedString ?? self
    }
}
#endif
