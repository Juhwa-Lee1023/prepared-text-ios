#if canImport(UIKit) && !os(macOS)
import CoreText
import PretextCore
import PretextSwiftUI
import SwiftUI
import UIKit
import XCTest
@testable import PretextUIKit

@MainActor
final class PreparedTextUIKitTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            PreparedTextLegacySupport._resetUILabelSupportForTesting()
            PreparedTextSystem.shared.measurer.invalidateAll()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            PreparedTextLegacySupport._resetUILabelSupportForTesting()
            PreparedTextSystem.shared.measurer.invalidateAll()
        }
        super.tearDown()
    }

    func testMeasurementCachingLabelSmokeSizing() {
        let label = MeasurementCachingLabel()
        label.attributedText = text("Measurement caching label smoke test for stage 0.")
        label.sourceID = PreparedTextSourceID("ios-smoke-stage0")

        let size = label.sizeThatFits(CGSize(width: 180, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertGreaterThan(size.height, 0)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertLessThanOrEqual(size.width, 180)
    }

    func testPreparedLabelViewSmokeSizing() {
        let view = PreparedLabelView()
        view.prepared(
            attributedText: text("Prepared label smoke test for iOS simulator."),
            sourceID: PreparedTextSourceID("ios-smoke-label"),
            whiteSpaceMode: .uikitLiteral,
            maxLayoutWidth: 180
        )

        let size = view.sizeThatFits(CGSize(width: 180, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertGreaterThan(size.height, 0)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertLessThanOrEqual(size.width, 180)
    }

    func testUILabelPreparedOptInUsesStage0MeasurementPathOnceSupportIsInstalled() {
        PreparedTextLegacySupport.installUILabelSupport(.optInOnly)

        let label = UILabel().prepared(sourceID: PreparedTextSourceID("ios-stage0-opt-in"), installIfNeeded: false)
        label.numberOfLines = 0
        label.attributedText = text("Legacy UILabel should opt into Stage 0 measurement caching only.")

        let before = PreparedTextSystem.shared.measurer.stats.totalCount
        let size = label.sizeThatFits(CGSize(width: 150, height: CGFloat.greatestFiniteMagnitude))
        let after = PreparedTextSystem.shared.measurer.stats.totalCount

        XCTAssertGreaterThan(size.height, 0)
        XCTAssertGreaterThan(after, before)
    }

    func testUILabelPreparedLazyInstallInstallsOptInSupport() {
        XCTAssertNil(PreparedTextLegacySupport.currentUILabelSupportConfiguration())

        let label = UILabel().prepared(sourceID: PreparedTextSourceID("ios-stage0-lazy-install"))
        label.numberOfLines = 0
        label.attributedText = text("Lazy install should bring in opt-in-only UILabel sizing support.")

        let size = label.sizeThatFits(CGSize(width: 160, height: CGFloat.greatestFiniteMagnitude))

        XCTAssertEqual(PreparedTextLegacySupport.currentUILabelSupportConfiguration(), .optInOnly)
        XCTAssertGreaterThan(size.height, 0)
        XCTAssertGreaterThan(PreparedTextSystem.shared.measurer.stats.totalCount, 0)
    }

    func testUILabelUnpreparedOptsOutUnderGlobalInstall() {
        PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)

        let label = UILabel().unprepared()
        label.numberOfLines = 0
        label.attributedText = text("Explicit opt-out should skip automatic Stage 0 UILabel adoption.")

        let before = PreparedTextSystem.shared.measurer.stats.totalCount
        _ = label.sizeThatFits(CGSize(width: 160, height: CGFloat.greatestFiniteMagnitude))
        let after = PreparedTextSystem.shared.measurer.stats.totalCount

        XCTAssertEqual(after, before)
    }

    func testLegacyMultilineAutoAdoptsUnlimitedMultilineLabelsButNotSingleOrFiniteLineLabels() {
        PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)

        let multiline = UILabel()
        multiline.numberOfLines = 0
        multiline.attributedText = text("Multiline UILabels should pick up Stage 0 sizing in legacy rollout mode.")

        let singleLine = UILabel()
        singleLine.numberOfLines = 1
        singleLine.attributedText = text("Single line labels stay out of the default rollout.")

        let finiteLineLimit = UILabel()
        finiteLineLimit.numberOfLines = 2
        finiteLineLimit.attributedText = text("Finite line-limited labels keep system truncation semantics during legacy rollout.")

        let before = PreparedTextSystem.shared.measurer.stats.totalCount
        _ = multiline.sizeThatFits(CGSize(width: 160, height: CGFloat.greatestFiniteMagnitude))
        let afterMultiline = PreparedTextSystem.shared.measurer.stats.totalCount
        _ = singleLine.sizeThatFits(CGSize(width: 160, height: CGFloat.greatestFiniteMagnitude))
        let afterSingleLine = PreparedTextSystem.shared.measurer.stats.totalCount
        _ = finiteLineLimit.sizeThatFits(CGSize(width: 160, height: CGFloat.greatestFiniteMagnitude))
        let afterFiniteLimit = PreparedTextSystem.shared.measurer.stats.totalCount

        XCTAssertGreaterThan(afterMultiline, before)
        XCTAssertEqual(afterSingleLine, afterMultiline)
        XCTAssertEqual(afterFiniteLimit, afterSingleLine)
    }

    func testLegacyMultilineExcludesAttributedLinksFromAutomaticAdoption() {
        PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)

        let label = UILabel()
        label.numberOfLines = 0
        let linked = NSMutableAttributedString(
            string: "Linked legacy label",
            attributes: [.font: UIFont.systemFont(ofSize: 17)]
        )
        linked.addAttribute(.link, value: URL(string: "https://example.com")!, range: NSRange(location: 0, length: linked.length))
        label.attributedText = linked

        let before = PreparedTextSystem.shared.measurer.stats.totalCount
        _ = label.sizeThatFits(CGSize(width: 180, height: CGFloat.greatestFiniteMagnitude))
        let after = PreparedTextSystem.shared.measurer.stats.totalCount

        XCTAssertEqual(after, before)
    }

    func testLegacyMultilineExcludesInteractiveLabelsFromAutomaticAdoption() {
        PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)

        let label = UILabel()
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        label.attributedText = text("Interactive labels should remain outside automatic Stage 0 rollout.")

        let before = PreparedTextSystem.shared.measurer.stats.totalCount
        _ = label.sizeThatFits(CGSize(width: 180, height: CGFloat.greatestFiniteMagnitude))
        let after = PreparedTextSystem.shared.measurer.stats.totalCount

        XCTAssertEqual(after, before)
    }

    func testLegacyUILabelAdoptionDiagnosticsExplainFiniteLineExclusion() {
        PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)

        let label = UILabel()
        label.numberOfLines = 2
        label.attributedText = text("Finite line labels should keep system truncation semantics in Stage 0.")

        let diagnostics = PreparedTextLegacySupport.adoptionDiagnostics(for: label)
        XCTAssertFalse(diagnostics.usesPreparedMeasurement)
        XCTAssertEqual(diagnostics.reason, .finiteLineLimitRequiresStage1)
        XCTAssertEqual(diagnostics.sizing, .sizeThatFits)
    }

    func testLegacyUILabelAdoptionDiagnosticsExplainMissingInstall() {
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = text("Adoption diagnostics should explain when support is not installed.")

        let diagnostics = PreparedTextLegacySupport.adoptionDiagnostics(for: label)
        XCTAssertFalse(diagnostics.usesPreparedMeasurement)
        XCTAssertEqual(diagnostics.reason, .supportNotInstalled)
    }

    func testExplicitlyEnabledUILabelRespectsSystemLayoutSizingOptOut() {
        PreparedTextLegacySupport.installUILabelSupport(
            LegacyUILabelSupportConfiguration(
                scope: .optInOnly,
                swizzleSystemLayoutSizeFitting: false
            )
        )

        let label = UILabel().prepared(
            sourceID: PreparedTextSourceID("ios-stage0-explicit-system-layout-opt-out"),
            installIfNeeded: false
        )
        label.numberOfLines = 0
        label.attributedText = text("Explicit opt-in should still respect Stage 0 systemLayoutSizeFitting opt-out.")

        let diagnostics = PreparedTextLegacySupport.adoptionDiagnostics(
            for: label,
            sizing: .systemLayoutSizeFitting
        )
        XCTAssertFalse(diagnostics.usesPreparedMeasurement)
        XCTAssertEqual(diagnostics.reason, .systemLayoutSizingNotSwizzled)

        let preparedMeasurement = PreparedTextLegacySupport.preparedMeasurementSize(
            for: label,
            sizing: .systemLayoutSizeFitting(
                CGSize(width: 180, height: UIView.layoutFittingCompressedSize.height),
                .required
            )
        )
        XCTAssertNil(preparedMeasurement)
    }

    func testMeasurementCachingLabelPreparedSetsSourceID() {
        let sourceID = PreparedTextSourceID("ios-measurement-label-prepared")
        let label: MeasurementCachingLabel = MeasurementCachingLabel().prepared(
            sourceID: sourceID,
            measurementOptions: .default
        )
        XCTAssertEqual(label.sourceID, sourceID)
    }

    func testMeasurementCachingLabelPreparedAppliesMeasurementOptions() {
        let measurementOptions = PreparedTextMeasurementOptions(
            widthNormalizationPolicy: .bucketed(points: 4),
            pixelMeasurementPolicy: .alignedToScale
        )
        let label = MeasurementCachingLabel().prepared(
            sourceID: PreparedTextSourceID("ios-measurement-options"),
            measurementOptions: measurementOptions
        )

        XCTAssertEqual(label.measurementOptions, measurementOptions)
    }

    func testMeasurementCachingLabelPreparedAppliesCacheProfile() {
        let label = MeasurementCachingLabel().prepared(
            sourceID: PreparedTextSourceID("ios-cache-profile"),
            cacheProfile: .stickyPrepared
        )

        XCTAssertEqual(label.measurementOptions, PreparedTextCacheProfile.stickyPrepared.measurementOptions)
    }

    func testPreparedLabelViewPreparedAppliesFluentConfiguration() {
        let attributedText = text("PreparedLabelView fluent API should only configure existing Stage 1 behavior.")
        let view = PreparedLabelView().prepared(
            attributedText: attributedText,
            sourceID: PreparedTextSourceID("ios-prepared-label-fluent"),
            whiteSpaceMode: .preWrap,
            maxLayoutWidth: 140,
            numberOfLines: 2,
            lineBreakMode: .byWordWrapping,
            textAlignment: .center,
            automaticallyOpensLinks: false
        )

        XCTAssertEqual(view.configuration.attributedText?.string, attributedText.string)
        XCTAssertEqual(view.configuration.sourceID, PreparedTextSourceID("ios-prepared-label-fluent"))
        XCTAssertEqual(view.configuration.whiteSpaceMode, .preWrap)
        XCTAssertEqual(view.configuration.maxLayoutWidth, 140)
        XCTAssertEqual(view.configuration.numberOfLines, 2)
        XCTAssertEqual(view.configuration.lineBreakMode, .byWordWrapping)
        XCTAssertEqual(view.configuration.textAlignment, .center)
        XCTAssertFalse(view.configuration.automaticallyOpensLinks)
    }

    func testPreparedLabelViewPreparedAppliesMeasurementOptions() {
        let measurementOptions = PreparedTextMeasurementOptions(
            widthNormalizationPolicy: .bucketed(points: 2),
            pixelMeasurementPolicy: .alignedToScale
        )
        let view = PreparedLabelView().prepared(
            attributedText: text("Stage 1 measurement options should flow into public configuration."),
            sourceID: PreparedTextSourceID("ios-stage1-measurement-options"),
            measurementOptions: measurementOptions,
            maxLayoutWidth: 180
        )

        XCTAssertEqual(view.configuration.measurementOptions, measurementOptions)
    }

    func testPreparedLabelViewPreparedAppliesCacheProfile() {
        let view = PreparedLabelView().prepared(
            attributedText: text("PreparedLabelView should accept public cache profile presets."),
            sourceID: PreparedTextSourceID("ios-stage1-cache-profile"),
            cacheProfile: .balanced,
            maxLayoutWidth: 180
        )

        XCTAssertEqual(view.configuration.measurementOptions, PreparedTextCacheProfile.balanced.measurementOptions)
    }

    func testPreparedLabelViewPreparedAcceptsLayoutOptions() {
        let layoutOptions = PreparedTextLayoutOptions(
            maximumNumberOfLines: 2,
            lineBreakMode: .truncateMiddle,
            lineBreakStrategy: .nativeTypesetterPreferred,
            alignment: .center,
            layoutDirection: .rightToLeft
        )
        let view = PreparedLabelView().prepared(
            attributedText: text("PreparedLabelView should accept promoted layout options directly."),
            sourceID: PreparedTextSourceID("ios-layout-options"),
            maxLayoutWidth: 160,
            layoutOptions: layoutOptions
        )

        XCTAssertEqual(view.configuration.layoutOptions, layoutOptions)
        XCTAssertEqual(view.configuration.numberOfLines, 2)
        XCTAssertEqual(view.configuration.lineBreakMode, .byTruncatingMiddle)
        XCTAssertEqual(view.configuration.lineBreakStrategy, .nativeTypesetterPreferred)
        XCTAssertEqual(view.lineBreakStrategy, .nativeTypesetterPreferred)
        XCTAssertEqual(view.configuration.textAlignment, .center)
    }

    func testPreparedLabelViewExposesPublicTruncationStateAndVisibleRange() {
        let view = PreparedLabelView().prepared(
            attributedText: text("Prepared label views should expose read-only truncation state and visible range helpers."),
            sourceID: PreparedTextSourceID("ios-public-truncation-state"),
            maxLayoutWidth: 120,
            layoutOptions: PreparedTextLayoutOptions(
                maximumNumberOfLines: 1,
                lineBreakMode: .truncateTail,
                lineBreakStrategy: .automatic,
                alignment: .natural,
                layoutDirection: .leftToRight,
                truncationToken: PreparedTruncationToken(text: "[more]", attributeBehavior: .plain)
            )
        )

        _ = view.sizeThatFits(CGSize(width: 120, height: CGFloat.greatestFiniteMagnitude))

        XCTAssertEqual(view.isTruncated(), true)
        XCTAssertNotNil(view.visibleTextRange())
        XCTAssertFalse(view.visibleTextRanges()?.isEmpty ?? true)
    }

    func testPreparedTextViewSugarFromStringCompilesAndRenders() {
        let view: PreparedTextView = "Hello prepared string".prepared(numberOfLines: 2)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testPreparedTextViewStoresMeasurementOptions() {
        let measurementOptions = PreparedTextMeasurementOptions(
            widthNormalizationPolicy: .bucketed(points: 4),
            pixelMeasurementPolicy: .alignedToScale
        )
        let view = PreparedTextView(
            attributedText: NSAttributedString(string: "Hello prepared view"),
            measurementOptions: measurementOptions
        )

        XCTAssertEqual(view.measurementOptions, measurementOptions)
    }

    func testPreparedTextViewStoresLayoutOptions() {
        let layoutOptions = PreparedTextLayoutOptions(
            maximumNumberOfLines: 1,
            lineBreakMode: .truncateMiddle,
            lineBreakStrategy: .urlFriendly,
            alignment: .trailing,
            layoutDirection: .rightToLeft
        )
        let view = PreparedTextView(
            attributedText: NSAttributedString(string: "Hello prepared view"),
            layoutOptions: layoutOptions
        )

        XCTAssertEqual(view.layoutOptions, layoutOptions)
        XCTAssertEqual(view.numberOfLines, 1)
        XCTAssertEqual(view.lineBreakMode, .byTruncatingMiddle)
        XCTAssertEqual(view.lineBreakStrategy, .urlFriendly)
    }

    func testPreparedLabelViewPreservesAbsoluteTextAlignment() {
        let view = PreparedLabelView()
        view.textAlignment = .right

        XCTAssertEqual(view.layoutOptions.alignment, .right)
        XCTAssertEqual(view.textAlignment, .right)

        view.textAlignment = .left

        XCTAssertEqual(view.layoutOptions.alignment, .left)
        XCTAssertEqual(view.textAlignment, .left)
    }

    func testPreparedTextViewPreservesAbsoluteTextAlignment() {
        var view = PreparedTextView(
            attributedText: NSAttributedString(string: "Hello prepared view"),
            textAlignment: .right
        )

        XCTAssertEqual(view.layoutOptions.alignment, .right)
        XCTAssertEqual(view.textAlignment, .right)

        view.textAlignment = .left

        XCTAssertEqual(view.layoutOptions.alignment, .left)
        XCTAssertEqual(view.textAlignment, .left)
    }

    func testPreparedTextViewSugarFromAttributedStringCompilesAndRenders() {
        let view: PreparedTextView = AttributedString("Hello prepared attributed string").prepared(numberOfLines: 2)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testPreparedTextViewSugarFromNSAttributedStringCompilesAndRenders() {
        let view: PreparedTextView = NSAttributedString(string: "Hello prepared NSAttributedString").prepared(numberOfLines: 2)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testExperimentalTextPreparedFromStringCompilesAndRenders() {
        let view: PreparedTextView = Text("Hello").prepared(source: "Hello", numberOfLines: 2)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testExperimentalTextPreparedFromVerbatimStringCompilesAndRenders() {
        let raw = "Hello raw"
        let view: PreparedTextView = Text(verbatim: raw).prepared(source: raw, numberOfLines: 2)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testExperimentalTextPreparedFromAttributedStringCompilesAndRenders() {
        let source = AttributedString("Hello attributed source")
        let view: PreparedTextView = Text("Hello").prepared(source: source, numberOfLines: 2)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testExperimentalTextPreparedFromNSAttributedStringCompilesAndRenders() {
        let source = NSAttributedString(string: "Hello NSAttributed source")
        let view: PreparedTextView = Text("Hello").prepared(source: source, numberOfLines: 2)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testExperimentalTextPreparedFromPreparedTextCompilesAndRenders() {
        let prepared = PreparedTextSystem.shared.engine.prepare(
            text("Hello experimental handle"),
            sourceID: PreparedTextSourceID("ios-experimental-text-prepared-handle"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )
        let view: PreparedTextView = Text("Hello").prepared(source: prepared, numberOfLines: 2)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testPreparedTextViewSugarFromPreparedTextCompilesAndRenders() {
        let prepared = PreparedTextSystem.shared.engine.prepare(
            text("Hello prepared handle"),
            sourceID: PreparedTextSourceID("ios-prepared-handle-sugar"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )
        let view: PreparedTextView = prepared.prepared(numberOfLines: 2)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testPreparedCopyCompilesForStringInputs() {
        let host = UIHostingController(rootView: PreparedCopy("Hello prepared copy", numberOfLines: 2))
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testPreparedCopyCompilesForPreparedTextInputs() {
        let prepared = PreparedTextSystem.shared.engine.prepare(
            text("Hello prepared copy handle"),
            sourceID: PreparedTextSourceID("ios-prepared-copy-handle"),
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral)
        )
        let host = UIHostingController(rootView: PreparedCopy(prepared, numberOfLines: 2))
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testPreparedLabelViewReappliesMutableAttributedTextByValue() {
        let mutable = NSMutableAttributedString(string: "Short")
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: NSRange(location: 0, length: mutable.length))

        let view = PreparedLabelView()
        view.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: mutable,
                sourceID: PreparedTextSourceID("ios-mutable-reapply"),
                whiteSpaceMode: .uikitLiteral,
                maxLayoutWidth: 110
            )
        )

        let originalSize = view.sizeThatFits(CGSize(width: 110, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertEqual(view.accessibilityLabel, "Short")

        mutable.mutableString.setString("This mutable attributed string became much longer after the first apply call.")
        mutable.setAttributes([.font: UIFont.systemFont(ofSize: 17)], range: NSRange(location: 0, length: mutable.length))

        view.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: mutable,
                sourceID: PreparedTextSourceID("ios-mutable-reapply"),
                whiteSpaceMode: .uikitLiteral,
                maxLayoutWidth: 110
            )
        )

        let updatedSize = view.sizeThatFits(CGSize(width: 110, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertEqual(view.accessibilityLabel, mutable.string)
        XCTAssertGreaterThan(updatedSize.height, originalSize.height)
    }

    func testPreparedLabelViewNumberOfLinesReducesMeasuredHeight() {
        let content = text("Prepared label view should clamp long multiline content when a line limit is set.")
        let view = PreparedLabelView()
        view.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: content,
                sourceID: PreparedTextSourceID("ios-line-limit"),
                whiteSpaceMode: .uikitLiteral,
                maxLayoutWidth: 120
            )
        )
        let unlimited = view.sizeThatFits(CGSize(width: 120, height: CGFloat.greatestFiniteMagnitude))

        view.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: content,
                sourceID: PreparedTextSourceID("ios-line-limit"),
                whiteSpaceMode: .uikitLiteral,
                maxLayoutWidth: 120,
                numberOfLines: 2,
                lineBreakMode: .byTruncatingTail
            )
        )
        let limited = view.sizeThatFits(CGSize(width: 120, height: CGFloat.greatestFiniteMagnitude))

        XCTAssertLessThan(limited.height, unlimited.height)
    }

    func testPreparedLabelViewLinkActivationUsesAlignmentAwareHitTesting() {
        let url = URL(string: "https://example.com/link")!
        let attributed = NSMutableAttributedString(
            string: "Linked center text",
            attributes: [.font: UIFont.systemFont(ofSize: 17)]
        )
        attributed.addAttribute(.link, value: url, range: NSRange(location: 0, length: attributed.length))

        let expectation = expectation(description: "link handler invoked")
        var activatedURL: URL?
        let view = PreparedLabelView()
        view.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: attributed,
                sourceID: PreparedTextSourceID("ios-link-hit-test"),
                whiteSpaceMode: .uikitLiteral,
                maxLayoutWidth: 200,
                textAlignment: .center,
                automaticallyOpensLinks: false,
                linkTapHandler: { tappedURL in
                    activatedURL = tappedURL
                    expectation.fulfill()
                }
            )
        )

        let size = view.sizeThatFits(CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude))
        view.frame = CGRect(x: 0, y: 0, width: 200, height: size.height)

        XCTAssertNil(view.link(at: CGPoint(x: 4, y: size.height / 2)))
        XCTAssertEqual(view.link(at: CGPoint(x: 100, y: size.height / 2)), url)
        XCTAssertTrue(view.activateLink(at: CGPoint(x: 100, y: size.height / 2)))

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(activatedURL, url)
    }

    func testPreparedLabelViewSourceCoordinateMapReflectsTruncatedDisplay() {
        let view = PreparedLabelView()
        view.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: text("Alpha Beta Gamma Delta Epsilon"),
                sourceID: PreparedTextSourceID("ios-source-coordinate-map"),
                whiteSpaceMode: .uikitLiteral,
                maxLayoutWidth: 100,
                layoutOptions: PreparedTextLayoutOptions(
                    maximumNumberOfLines: 1,
                    lineBreakMode: .truncateMiddle,
                    alignment: .natural,
                    layoutDirection: .leftToRight
                )
            )
        )

        let size = view.sizeThatFits(CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        view.frame = CGRect(x: 0, y: 0, width: 100, height: size.height)

        let map = view.sourceCoordinateMap()
        XCTAssertEqual(map?.lines.count, 1)
        XCTAssertGreaterThan(map?.lines.first?.sourceSpans.count ?? 0, 3)
        XCTAssertFalse(map?.lines.first?.visibleSourceUTF16Ranges.isEmpty ?? true)
        XCTAssertTrue(map?.lines.first?.isTruncated ?? false)
    }

    func testPreparedLabelViewVisibleAnnotationsFollowTruncatedDisplay() {
        let visibleURL = URL(string: "https://example.com/visible-annotation")!
        let hiddenURL = URL(string: "https://example.com/hidden-annotation")!
        let attributed = NSMutableAttributedString(
            string: "Visible #first\nHidden @second",
            attributes: [.font: UIFont.systemFont(ofSize: 17)]
        )
        attributed.addAttribute(.link, value: visibleURL, range: NSRange(location: 8, length: 6))
        attributed.addAttribute(.link, value: hiddenURL, range: NSRange(location: 22, length: 7))

        let view = PreparedLabelView()
        view.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: attributed,
                sourceID: PreparedTextSourceID("ios-visible-annotations"),
                whiteSpaceMode: .uikitLiteral,
                maxLayoutWidth: 220,
                numberOfLines: 1,
                lineBreakMode: .byTruncatingTail,
                automaticallyOpensLinks: false
            )
        )

        let annotations = view.visibleAnnotations()
        XCTAssertEqual(annotations?.map(\.kind), [.link, .hashtag])
        XCTAssertEqual(annotations?.first?.linkDestination, visibleURL.absoluteString)
    }

    func testPreparedLabelViewKeepsOnlyVisibleLinksForAccessibilityWhenClippedAtHardBreak() {
        let visibleURL = URL(string: "https://example.com/visible")!
        let hiddenURL = URL(string: "https://example.com/hidden")!
        let attributed = NSMutableAttributedString(
            string: "Visible\nHidden",
            attributes: [.font: UIFont.systemFont(ofSize: 17)]
        )
        attributed.addAttribute(.link, value: visibleURL, range: NSRange(location: 0, length: 7))
        attributed.addAttribute(.link, value: hiddenURL, range: NSRange(location: 8, length: 6))

        let expectation = expectation(description: "visible accessibility link activated")
        var activatedURL: URL?
        let view = PreparedLabelView()
        view.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: attributed,
                sourceID: PreparedTextSourceID("ios-accessibility-visible-links"),
                whiteSpaceMode: .uikitLiteral,
                maxLayoutWidth: 220,
                numberOfLines: 1,
                lineBreakMode: .byTruncatingTail,
                automaticallyOpensLinks: false,
                linkTapHandler: { tappedURL in
                    activatedURL = tappedURL
                    expectation.fulfill()
                }
            )
        )

        let size = view.sizeThatFits(CGSize(width: 220, height: CGFloat.greatestFiniteMagnitude))
        view.frame = CGRect(x: 0, y: 0, width: 220, height: size.height)

        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertNil(view.accessibilityElements)
        XCTAssertEqual(view.accessibilityCustomActions?.count, 1)
        XCTAssertEqual(view.accessibilityCustomActions?.first?.name, "Visible")
        XCTAssertTrue(view.accessibilityActivate())

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(activatedURL, visibleURL)
    }

    func testPreparedLabelViewWordWrappingDoesNotExposeHiddenLinksFromLaterLines() {
        let visibleURL = URL(string: "https://example.com/wrap-visible")!
        let hiddenURL = URL(string: "https://example.com/wrap-hidden")!
        let attributed = NSMutableAttributedString(
            string: "Visible\nHidden",
            attributes: [.font: UIFont.systemFont(ofSize: 17)]
        )
        attributed.addAttribute(.link, value: visibleURL, range: NSRange(location: 0, length: 7))
        attributed.addAttribute(.link, value: hiddenURL, range: NSRange(location: 8, length: 6))

        let view = PreparedLabelView()
        view.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: attributed,
                sourceID: PreparedTextSourceID("ios-word-wrap-visible-links"),
                whiteSpaceMode: .uikitLiteral,
                maxLayoutWidth: 220,
                numberOfLines: 1,
                lineBreakMode: .byWordWrapping,
                automaticallyOpensLinks: false
            )
        )

        let size = view.sizeThatFits(CGSize(width: 220, height: CGFloat.greatestFiniteMagnitude))
        view.frame = CGRect(x: 0, y: 0, width: 220, height: size.height)

        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertNil(view.accessibilityElements)
        XCTAssertEqual(view.accessibilityCustomActions?.count, 1)
        XCTAssertEqual(view.accessibilityCustomActions?.first?.name, "Visible")
    }

    func testPreparedLabelViewPromotesMultipleVisibleLinksToAccessibilityElements() throws {
        let firstURL = URL(string: "https://example.com/first-link")!
        let secondURL = URL(string: "https://example.com/second-link")!
        let attributed = NSMutableAttributedString(
            string: "First link and second link stay individually focusable.",
            attributes: [.font: UIFont.systemFont(ofSize: 17)]
        )
        let firstRange = (attributed.string as NSString).range(of: "First link")
        let secondRange = (attributed.string as NSString).range(of: "second link")
        attributed.addAttribute(.link, value: firstURL, range: firstRange)
        attributed.addAttribute(.link, value: secondURL, range: secondRange)

        let expectation = expectation(description: "both accessibility links activated")
        expectation.expectedFulfillmentCount = 2
        var activatedURLs: [URL] = []

        let view = PreparedLabelView()
        view.apply(
            configuration: PreparedLabelConfiguration(
                attributedText: attributed,
                sourceID: PreparedTextSourceID("ios-accessibility-multiple-links"),
                whiteSpaceMode: .uikitLiteral,
                maxLayoutWidth: 260,
                automaticallyOpensLinks: false,
                linkTapHandler: { tappedURL in
                    activatedURLs.append(tappedURL)
                    expectation.fulfill()
                }
            )
        )

        let size = view.sizeThatFits(CGSize(width: 260, height: CGFloat.greatestFiniteMagnitude))
        view.frame = CGRect(x: 0, y: 0, width: 260, height: size.height)
        view.layoutIfNeeded()

        XCTAssertFalse(view.isAccessibilityElement)
        let elements = try XCTUnwrap(view.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertEqual(elements.count, 3)
        XCTAssertEqual(elements[0].accessibilityLabel, attributed.string)
        XCTAssertEqual(elements[1].accessibilityLabel, "First link")
        XCTAssertEqual(elements[2].accessibilityLabel, "second link")
        XCTAssertFalse(elements[1].accessibilityFrameInContainerSpace.isEmpty)
        XCTAssertFalse(elements[2].accessibilityFrameInContainerSpace.isEmpty)
        XCTAssertTrue(elements[1].accessibilityActivate())
        XCTAssertTrue(elements[2].accessibilityActivate())

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(activatedURLs, [firstURL, secondURL])
    }

    func testPreparedLabelViewTapGestureDoesNotCancelTouchesInView() throws {
        let view = PreparedLabelView()
        let tapGestureRecognizer = try XCTUnwrap(
            view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.first
        )

        XCTAssertFalse(tapGestureRecognizer.cancelsTouchesInView)
    }

    func testUIKitDemoSamplesReturnEmptyArrayForZeroCount() {
        XCTAssertTrue(PreparedTextUIKitDemoItem.makeSamples(count: 0).isEmpty)
    }

    func testDemoLanguagePrefersExplicitHansScriptOverRegionHeuristics() {
        XCTAssertEqual(PreparedTextDemoLanguage.from(identifier: "zh-Hans-HK"), .chineseSimplified)
        XCTAssertEqual(PreparedTextDemoLanguage.from(identifier: "zh_Hant_CN"), .chineseTraditional)
    }

    func testPreparedTextShowcaseViewDefaultInitializerDoesNotNeedEnvironmentObject() {
        let host = UIHostingController(rootView: PreparedTextShowcaseView())
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testPreparedTextObstacleShowcaseViewDefaultInitializerDoesNotNeedEnvironmentObject() {
        let host = UIHostingController(rootView: PreparedTextObstacleShowcaseView())
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testObstacleDemoFixedCircleProducesSplitRows() {
        let view = PreparedTextObstacleDemoView()
        view.apply(
            configuration: PreparedTextObstacleDemoConfiguration(
                attributedText: text("Obstacle-aware demo text should split a few visual rows when a large circle sits in the center of the card."),
                sourceID: PreparedTextSourceID("ios-obstacle-fixed"),
                mode: .fixed([
                    PreparedTextObstacleCircle(center: CGPoint(x: 160, y: 120), radius: 46),
                ]),
                preferredHeight: 260
            )
        )

        let snapshot = view.debugLayoutSnapshot(in: CGRect(x: 0, y: 0, width: 320, height: 260))

        XCTAssertEqual(snapshot.obstacleCount, 1)
        XCTAssertGreaterThan(snapshot.rowCount, 0)
        XCTAssertGreaterThan(snapshot.fragmentCount, 0)
        XCTAssertGreaterThan(snapshot.splitRowCount, 0)
        XCTAssertFalse(snapshot.renderedStrings.joined().isEmpty)
    }

    func testObstacleDemoTouchModeEnablesPanGestureAndPreferredHeight() {
        let view = PreparedTextObstacleDemoView()
        view.apply(
            configuration: PreparedTextObstacleDemoConfiguration(
                attributedText: text("Dragging across the card should leave a temporary trail that text bends around."),
                sourceID: PreparedTextSourceID("ios-obstacle-touch"),
                mode: .touchTrail,
                preferredHeight: 244
            )
        )

        let panGestureRecognizer = view.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }.first

        XCTAssertEqual(view.intrinsicContentSize.height, 244, accuracy: 0.5)
        XCTAssertNotNil(panGestureRecognizer)
        XCTAssertEqual(panGestureRecognizer?.isEnabled, true)
    }

    func testObstacleDemoBouncingBallsProducesMultipleAnimatedObstacles() {
        let view = PreparedTextObstacleDemoView()
        view.apply(
            configuration: PreparedTextObstacleDemoConfiguration(
                attributedText: text("Bouncing obstacle demo text should reopen narrow channels while several round obstacles ricochet across the card."),
                sourceID: PreparedTextSourceID("ios-obstacle-bouncing-balls"),
                mode: .bouncingBalls,
                obstacleRadius: 30,
                preferredHeight: 260
            )
        )

        let snapshot = view.debugLayoutSnapshot(in: CGRect(x: 0, y: 0, width: 320, height: 260))

        XCTAssertGreaterThan(snapshot.obstacleCount, 1)
        XCTAssertGreaterThan(snapshot.rowCount, 0)
        XCTAssertGreaterThan(snapshot.fragmentCount, 0)
        XCTAssertGreaterThan(snapshot.splitRowCount, 0)
        XCTAssertFalse(snapshot.renderedStrings.joined().isEmpty)
    }

    func testPreparedTextObstacleLayouterProducesReusablePublicLayoutResult() {
        let prepared = PreparedTextSystem.shared.prepare(
            text("Public obstacle layouter should split rows when circles carve exclusion spans into the prepared surface."),
            sourceID: PreparedTextSourceID("ios-obstacle-layouter")
        )
        let layouter = PreparedTextObstacleLayouter(textSystem: .shared)
        let result = layouter.layout(
            prepared: prepared,
            in: CGRect(x: 24, y: 24, width: 272, height: 220),
            obstacles: [
                PreparedTextObstacleCircle(center: CGPoint(x: 160, y: 96), radius: 40),
            ],
            lineHeight: prepared.defaultLineHeight,
            obstaclePadding: 12,
            minimumSpanWidth: 30
        )

        XCTAssertEqual(result.snapshot.obstacleCount, 1)
        XCTAssertGreaterThan(result.snapshot.rowCount, 0)
        XCTAssertGreaterThan(result.snapshot.fragmentCount, 0)
        XCTAssertGreaterThan(result.snapshot.splitRowCount, 0)
        XCTAssertFalse(result.snapshot.renderedStrings.joined().isEmpty)
    }

    func testPreparedTextObstacleLayouterExposesCoordinateMapAndVisibleTokens() {
        let prepared = PreparedTextSystem.shared.prepare(
            text("Obstacle-aware cards should keep #prepared and @team spans inspectable while circles carve out exclusion zones."),
            sourceID: PreparedTextSourceID("ios-obstacle-coordinate-map")
        )
        let layouter = PreparedTextObstacleLayouter(textSystem: .shared)
        let result = layouter.layout(
            prepared: prepared,
            in: CGRect(x: 24, y: 24, width: 272, height: 220),
            obstacles: [
                PreparedObstacle(circle: PreparedTextObstacleCircle(center: CGPoint(x: 160, y: 96), radius: 40)),
            ],
            lineHeight: prepared.defaultLineHeight,
            obstaclePadding: 12,
            minimumSpanWidth: 30
        )

        let map = result.sourceCoordinateMap(in: prepared)
        let tokens = result.visibleTokens(in: prepared)
        let hashtag = tokens.first(where: { $0.kind == .hashtag })
        let hashtagRects = hashtag.map { map.displayedRects(for: $0) } ?? []

        XCTAssertEqual(map.lines.count, result.fragments.count)
        XCTAssertEqual(result.snapshot.obstacleCount, 1)
        XCTAssertTrue(tokens.contains { $0.kind == .hashtag })
        XCTAssertTrue(tokens.contains { $0.kind == .mention })
        XCTAssertFalse(hashtagRects.isEmpty)
        XCTAssertTrue(hashtagRects.contains { $0.rect.isEmpty == false })
    }

    func testPreparedTextObstacleLayouterSupportsRoundedRectObstacles() {
        let prepared = PreparedTextSystem.shared.prepare(
            text("Rounded exclusion cards should keep #prepared and @team visible while a wide panel trims the middle rows."),
            sourceID: PreparedTextSourceID("ios-obstacle-rounded-rect")
        )
        let layouter = PreparedTextObstacleLayouter(textSystem: .shared)
        let result = layouter.layout(
            prepared: prepared,
            in: CGRect(x: 24, y: 24, width: 272, height: 220),
            obstacles: [
                PreparedObstacle(
                    roundedRect: PreparedTextObstacleRoundedRect(
                        rect: CGRect(x: 132, y: 70, width: 88, height: 92),
                        cornerRadius: 22
                    )
                ),
            ],
            lineHeight: prepared.defaultLineHeight,
            obstaclePadding: 10,
            minimumSpanWidth: 30
        )

        let map = result.sourceCoordinateMap(in: prepared)
        let hashtagRange = (prepared.source.string as NSString).range(of: "#prepared")
        let rects = map.displayedRects(forSourceUTF16Range: hashtagRange)

        XCTAssertEqual(result.snapshot.obstacleCount, 1)
        XCTAssertGreaterThan(result.snapshot.rowCount, 0)
        XCTAssertGreaterThan(result.snapshot.fragmentCount, 0)
        XCTAssertTrue(result.snapshot.splitRowCount > 0)
        XCTAssertNotNil(result.preparedObstacles.first?.roundedRect)
        XCTAssertFalse(rects.isEmpty)
        XCTAssertFalse(rects[0].rect.isEmpty)
    }

    func testPreparedTextObstacleLayouterKeepsVisibleRectsForRightToLeftRanges() {
        let attributed = NSMutableAttributedString(
            string: "بطاقات العوائق تحافظ على الروابط المرئية",
            attributes: [.font: UIFont.systemFont(ofSize: 19)]
        )
        let linkRange = (attributed.string as NSString).range(of: "الروابط")
        attributed.addAttribute(.link, value: URL(string: "https://example.com/links")!, range: linkRange)

        let prepared = PreparedTextSystem.shared.prepare(
            attributed,
            sourceID: PreparedTextSourceID("ios-obstacle-rtl-rects")
        )
        let layouter = PreparedTextObstacleLayouter(textSystem: .shared)
        let result = layouter.layout(
            prepared: prepared,
            in: CGRect(x: 24, y: 24, width: 272, height: 220),
            obstacles: [
                PreparedObstacle(circle: PreparedTextObstacleCircle(center: CGPoint(x: 160, y: 96), radius: 34)),
            ],
            lineHeight: prepared.defaultLineHeight,
            obstaclePadding: 10,
            minimumSpanWidth: 30
        )

        let rects = result.sourceCoordinateMap(in: prepared).displayedRects(forSourceUTF16Range: linkRange)

        XCTAssertFalse(rects.isEmpty)
        XCTAssertTrue(rects.contains { $0.rect.width > 0 })
    }

    func testObstacleDemoPreservesHardBreakAcrossSplitRows() {
        let view = PreparedTextObstacleDemoView()
        view.apply(
            configuration: PreparedTextObstacleDemoConfiguration(
                attributedText: text("Alpha\nBeta"),
                sourceID: PreparedTextSourceID("ios-obstacle-hard-break"),
                mode: .fixed([
                    PreparedTextObstacleCircle(center: CGPoint(x: 160, y: 42), radius: 56),
                ]),
                preferredHeight: 220
            )
        )

        let snapshot = view.debugLayoutSnapshot(in: CGRect(x: 0, y: 0, width: 320, height: 220))

        XCTAssertGreaterThan(snapshot.splitRowCount, 0)
        XCTAssertGreaterThanOrEqual(snapshot.rowCount, 2)
        XCTAssertEqual(snapshot.renderedStrings.first, "Alpha")
        XCTAssertTrue(snapshot.renderedStrings.contains("Beta"))
    }

    func testUIKitBaselinesSmoke() {
        let fixture = CorrectnessFixture(
            id: "ios-smoke-baseline",
            text: text("Prepared text baseline smoke path."),
            widths: [180],
            options: PreparedTextOptions(whiteSpaceMode: .uikitLiteral),
            lineHeight: 20,
            category: .strict
        )

        let labelSnapshot = UILabelComparator().snapshot(for: fixture, width: 180)
        let textViewSnapshot = UITextViewComparator().snapshot(for: fixture, width: 180)

        XCTAssertGreaterThan(labelSnapshot.lineCount, 0)
        XCTAssertGreaterThan(textViewSnapshot.lineCount, 0)
        XCTAssertGreaterThan(labelSnapshot.height, 0)
        XCTAssertGreaterThan(textViewSnapshot.height, 0)
    }

    func testStrictUIKitBaselineGate() {
        let engine = DefaultPreparedTextEngine()
        let harness = CorrectnessHarness(engine: engine)
        let report = harness.compareReport(
            fixtures: CorrectnessFixtureCatalog.simulatorGateCorpus(),
            baselines: [UILabelComparator(), UITextViewComparator()]
        )

        XCTAssertEqual(report.strictDiffCount, 0, report.strictDiffs.map(\.summaryLine).joined(separator: "\n"))
        XCTAssertTrue(report.strictGateFailures(heightThreshold: 1).isEmpty, report.strictGateFailures(heightThreshold: 1).joined(separator: "\n"))
    }

    private func text(_ string: String) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("Helvetica" as CFString, 17, nil)]
        )
    }
}
#endif
