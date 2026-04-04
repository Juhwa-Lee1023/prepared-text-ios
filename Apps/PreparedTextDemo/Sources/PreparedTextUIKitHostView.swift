#if canImport(SwiftUI) && canImport(UIKit)
import PretextUIKit
import SwiftUI
import UIKit

struct PreparedTextUIKitHostView: View {
    let language: PreparedTextDemoLanguage

    @State private var selectedPage: UIKitLabPage = .launchDefault
    @State private var pageContentHeight: CGFloat = 620
    @State private var containerWidth: Double = 360
    @State private var containerHeight: Double = 620
    @State private var previewWidth: Double = 232
    @State private var previewHeight: Double = 188
    @State private var itemCount: Double = 6

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(288.0, Double(proxy.size.width - 32))
            let resolvedWidth = CGFloat(min(containerWidth, availableWidth))
            let minimumCanvasHeight = max(CGFloat(containerHeight), max(360, proxy.size.height * 0.55))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker(localizedPickerTitle, selection: $selectedPage) {
                        ForEach(UIKitLabPage.allCases) { page in
                            Text(page.title(language: language)).tag(page)
                        }
                    }
                    .pickerStyle(.segmented)

                    controlsCard

                    HStack {
                        Spacer(minLength: 0)
                        UIKitPreparedTextPageView(
                            page: selectedPage,
                            language: language,
                            previewWidth: previewWidth,
                            previewHeight: previewHeight,
                            itemCount: Int(itemCount.rounded()),
                            measuredHeight: $pageContentHeight,
                            minimumHeight: minimumCanvasHeight
                        )
                        .id("\(selectedPage.rawValue)-\(language.rawValue)")
                        .frame(width: resolvedWidth, height: max(pageContentHeight, minimumCanvasHeight))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color(uiColor: UIColor.separator).opacity(0.22), lineWidth: 1)
                        }
                        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 8)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onChange(of: selectedPage) { _ in
            pageContentHeight = CGFloat(containerHeight)
        }
        .onChange(of: language) { _ in
            pageContentHeight = CGFloat(containerHeight)
        }
    }

    @ViewBuilder
    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(controlTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(controlCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: controlColumns, spacing: 10) {
                sliderTile(
                    title: localizedSurfaceWidthLabel,
                    value: "\(Int(containerWidth))pt",
                    range: 280...430,
                    step: 4,
                    binding: $containerWidth,
                    tint: .blue
                )

                sliderTile(
                    title: localizedSurfaceHeightLabel,
                    value: "\(Int(containerHeight))pt",
                    range: 420...760,
                    step: 8,
                    binding: $containerHeight,
                    tint: .indigo
                )

                switch selectedPage {
                case .overview:
                    sliderTile(
                        title: localizedWidthLabel,
                        value: "\(Int(previewWidth))pt",
                        range: 140...320,
                        step: 4,
                        binding: $previewWidth,
                        tint: .teal
                    )

                    sliderTile(
                        title: localizedHeightLabel,
                        value: "\(Int(previewHeight))pt",
                        range: 140...280,
                        step: 4,
                        binding: $previewHeight,
                        tint: .orange
                    )

                case .table, .collection:
                    sliderTile(
                        title: localizedCellCountLabel,
                        value: "\(Int(itemCount.rounded()))",
                        range: 2...18,
                        step: 1,
                        binding: $itemCount,
                        tint: .green
                    )
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(uiColor: UIColor.separator).opacity(0.22), lineWidth: 1)
        }
    }

    private var controlColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 120), spacing: 10),
            GridItem(.flexible(minimum: 120), spacing: 10),
        ]
    }

    private var controlCaption: String {
        switch language {
        case .english:
            return "Whole page scrolls together"
        case .korean:
            return "페이지 전체가 함께 스크롤됨"
        case .japanese:
            return "ページ全体が一緒にスクロール"
        case .chineseSimplified:
            return "整页一起滚动"
        case .chineseTraditional:
            return "整頁一起捲動"
        }
    }

    private func sliderTile(
        title: String,
        value: String,
        range: ClosedRange<Double>,
        step: Double,
        binding: Binding<Double>,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(value)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
            }

            Slider(value: binding, in: range, step: step)
                .tint(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var localizedPickerTitle: String {
        switch language {
        case .english:
            return "UIKit Page"
        case .korean:
            return "UIKit 페이지"
        case .japanese:
            return "UIKit ページ"
        case .chineseSimplified:
            return "UIKit 页面"
        case .chineseTraditional:
            return "UIKit 頁面"
        }
    }

    private var controlTitle: String {
        switch language {
        case .english:
            return "Live controls"
        case .korean:
            return "실시간 컨트롤"
        case .japanese:
            return "ライブコントロール"
        case .chineseSimplified:
            return "实时控制"
        case .chineseTraditional:
            return "即時控制"
        }
    }

    private var localizedWidthLabel: String {
        switch language {
        case .english:
            return "Preview width"
        case .korean:
            return "미리보기 너비"
        case .japanese:
            return "プレビュー幅"
        case .chineseSimplified:
            return "预览宽度"
        case .chineseTraditional:
            return "預覽寬度"
        }
    }

    private var localizedSurfaceWidthLabel: String {
        switch language {
        case .english:
            return "Host width"
        case .korean:
            return "호스트 너비"
        case .japanese:
            return "ホスト幅"
        case .chineseSimplified:
            return "宿主宽度"
        case .chineseTraditional:
            return "宿主寬度"
        }
    }

    private var localizedSurfaceHeightLabel: String {
        switch language {
        case .english:
            return "Host height"
        case .korean:
            return "호스트 높이"
        case .japanese:
            return "ホスト高さ"
        case .chineseSimplified:
            return "宿主高度"
        case .chineseTraditional:
            return "宿主高度"
        }
    }

    private var localizedHeightLabel: String {
        switch language {
        case .english:
            return "Preview height"
        case .korean:
            return "미리보기 높이"
        case .japanese:
            return "プレビュー高さ"
        case .chineseSimplified:
            return "预览高度"
        case .chineseTraditional:
            return "預覽高度"
        }
    }

    private var localizedCellCountLabel: String {
        switch language {
        case .english:
            return "Cell count"
        case .korean:
            return "셀 개수"
        case .japanese:
            return "セル数"
        case .chineseSimplified:
            return "单元数量"
        case .chineseTraditional:
            return "儲存格數量"
        }
    }
}

private enum UIKitLabPage: String, CaseIterable, Identifiable {
    case overview
    case table
    case collection

    var id: String { rawValue }

    static var launchDefault: Self {
        guard
            let rawValue = ProcessInfo.processInfo.environment["PRETEXT_UIKIT_PAGE"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            let page = Self(rawValue: rawValue)
        else {
            return .overview
        }
        return page
    }

    func title(language: PreparedTextDemoLanguage) -> String {
        switch (language, self) {
        case (.english, .overview):
            return "Overview"
        case (.english, .table):
            return "Table"
        case (.english, .collection):
            return "Collection"
        case (.korean, .overview):
            return "개요"
        case (.korean, .table):
            return "테이블"
        case (.korean, .collection):
            return "컬렉션"
        case (.japanese, .overview):
            return "概要"
        case (.japanese, .table):
            return "テーブル"
        case (.japanese, .collection):
            return "コレクション"
        case (.chineseSimplified, .overview):
            return "概览"
        case (.chineseSimplified, .table):
            return "表格"
        case (.chineseSimplified, .collection):
            return "集合"
        case (.chineseTraditional, .overview):
            return "概覽"
        case (.chineseTraditional, .table):
            return "表格"
        case (.chineseTraditional, .collection):
            return "集合"
        }
    }
}

private struct UIKitPreparedTextPageView: UIViewControllerRepresentable {
    let page: UIKitLabPage
    let language: PreparedTextDemoLanguage
    let previewWidth: Double
    let previewHeight: Double
    let itemCount: Int
    @Binding var measuredHeight: CGFloat
    let minimumHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = makeController()
        configureEmbeddedPage(controller, context: context)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        configureEmbeddedPage(uiViewController, context: context)
        switch (page, uiViewController) {
        case let (.overview, controller as PreparedTextOverviewDemoViewController):
            controller.apply(previewWidth: CGFloat(previewWidth), previewHeight: CGFloat(previewHeight))
        case let (.table, controller as PreparedTextTableDemoViewController):
            controller.apply(items: PreparedTextUIKitDemoItem.makeSamples(language: language, count: itemCount))
        case let (.collection, controller as PreparedTextCollectionDemoViewController):
            controller.apply(items: PreparedTextUIKitDemoItem.makeSamples(language: language, count: itemCount))
        default:
            break
        }

        if let embeddedPage = uiViewController as? (any PreparedTextUIKitEmbeddablePage) {
            DispatchQueue.main.async {
                embeddedPage.invalidateEmbeddedLayout()
            }
        }
    }

    private func makeController() -> UIViewController {
        switch page {
        case .overview:
            return PreparedTextOverviewDemoViewController(
                language: language,
                previewWidth: CGFloat(previewWidth),
                previewHeight: CGFloat(previewHeight)
            )
        case .table:
            return PreparedTextTableDemoViewController(
                items: PreparedTextUIKitDemoItem.makeSamples(language: language, count: itemCount),
                language: language
            )
        case .collection:
            return PreparedTextCollectionDemoViewController(
                items: PreparedTextUIKitDemoItem.makeSamples(language: language, count: itemCount),
                language: language
            )
        }
    }

    private func configureEmbeddedPage(_ controller: UIViewController, context: Context) {
        guard let embeddedPage = controller as? (any PreparedTextUIKitEmbeddablePage) else {
            return
        }

        embeddedPage.embeddedContentHeightDidChange = { height in
            context.coordinator.updateHeight(height, binding: $measuredHeight, minimumHeight: minimumHeight)
        }
        embeddedPage.setEmbeddedScrollingEnabled(false)
    }

    final class Coordinator {
        private var lastHeight: CGFloat = 0

        func updateHeight(_ rawHeight: CGFloat, binding: Binding<CGFloat>, minimumHeight: CGFloat) {
            let resolvedHeight = ceil(max(rawHeight, minimumHeight))
            guard abs(resolvedHeight - lastHeight) >= 0.5 else {
                return
            }

            lastHeight = resolvedHeight
            DispatchQueue.main.async {
                binding.wrappedValue = resolvedHeight
            }
        }
    }
}
#endif
