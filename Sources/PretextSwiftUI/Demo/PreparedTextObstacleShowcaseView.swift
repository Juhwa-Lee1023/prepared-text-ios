#if canImport(UIKit) && canImport(SwiftUI) && !os(macOS)
import PretextCore
import PretextUIKit
import SwiftUI
import UIKit

private enum PreparedObstaclePalette {
    static let backgroundStart = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.10, blue: 0.13, alpha: 1.0)
            : UIColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 1.0)
    })
    static let backgroundEnd = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.11, blue: 0.09, alpha: 1.0)
            : UIColor(red: 0.99, green: 0.97, blue: 0.94, alpha: 1.0)
    })
    static let panelBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let chipBackground = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.16, alpha: 1.0)
            : UIColor(white: 0.0, alpha: 0.06)
    })
    static let softStroke = Color(uiColor: UIColor.separator).opacity(0.22)
}

public struct PreparedTextObstacleShowcaseView: View {
    public let language: PreparedTextDemoLanguage
    @State private var selectedPage: ObstaclePage = .serpent
    @State private var touchRadius: Double = 36
    @State private var serpentSpeed: Double = 1.0
    @State private var bounceSpeed: Double = 1.0

    public init(language: PreparedTextDemoLanguage = .preferred) {
        self.language = language
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.title)
                        .font(.title3.weight(.semibold))

                    Text(copy.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Picker(copy.pickerTitle, selection: $selectedPage) {
                    ForEach(ObstaclePage.allCases) { page in
                        Text(page.shortTitle(language: language)).tag(page)
                    }
                }
                .pickerStyle(.segmented)

                TabView(selection: $selectedPage) {
                    ObstacleFullPage(
                        page: .serpent,
                        configuration: serpentConfiguration,
                        language: language,
                        serpentSpeed: $serpentSpeed
                    )
                    .tag(ObstaclePage.serpent)

                    ObstacleFullPage(
                        page: .bouncingBalls,
                        configuration: bouncingBallConfiguration,
                        language: language,
                        bounceSpeed: $bounceSpeed
                    )
                    .tag(ObstaclePage.bouncingBalls)

                    ObstacleFullPage(
                        page: .finger,
                        configuration: fingerConfiguration,
                        language: language,
                        touchRadius: $touchRadius
                    )
                    .tag(ObstaclePage.finger)
                }
                .frame(height: 620)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.22), value: selectedPage)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(
            LinearGradient(
                colors: [PreparedObstaclePalette.backgroundStart, PreparedObstaclePalette.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var copy: ObstacleCopy {
        ObstacleCopy(language: language)
    }

    private var serpentConfiguration: PreparedTextObstacleDemoConfiguration {
        PreparedTextObstacleDemoConfiguration(
            attributedText: obstacleText(lead: copy.serpentLead, body: copy.serpentBody, repeats: 3),
            sourceID: PreparedTextSourceID("obstacle-serpent-page"),
            whiteSpaceMode: .uikitLiteral,
            mode: .dragonOrbit,
            contentInsets: UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16),
            obstacleRadius: 32,
            obstaclePadding: 12,
            preferredHeight: 460,
            minimumSpanWidth: 20,
            orbitSpeedMultiplier: CGFloat(serpentSpeed)
        )
    }

    private var fingerConfiguration: PreparedTextObstacleDemoConfiguration {
        PreparedTextObstacleDemoConfiguration(
            attributedText: obstacleText(lead: copy.fingerLead, body: copy.fingerBody, repeats: 3),
            sourceID: PreparedTextSourceID("obstacle-finger-page"),
            whiteSpaceMode: .uikitLiteral,
            mode: .touchTrail,
            contentInsets: UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16),
            obstacleRadius: CGFloat(touchRadius),
            obstaclePadding: 10,
            preferredHeight: 460,
            minimumSpanWidth: 22
        )
    }

    private var bouncingBallConfiguration: PreparedTextObstacleDemoConfiguration {
        PreparedTextObstacleDemoConfiguration(
            attributedText: obstacleText(lead: copy.bouncingLead, body: copy.bouncingBody, repeats: 3),
            sourceID: PreparedTextSourceID("obstacle-bouncing-ball-page"),
            whiteSpaceMode: .uikitLiteral,
            mode: .bouncingBalls,
            contentInsets: UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16),
            obstacleRadius: 30,
            obstaclePadding: 10,
            preferredHeight: 460,
            minimumSpanWidth: 20,
            orbitSpeedMultiplier: CGFloat(bounceSpeed)
        )
    }

    private func obstacleText(lead: String, body: String, repeats: Int) -> NSAttributedString {
        let leadAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.label,
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .regular),
            .foregroundColor: UIColor.label,
        ]

        let text = NSMutableAttributedString(string: lead, attributes: leadAttributes)
        for index in 0..<max(repeats, 1) {
            text.append(NSAttributedString(string: body, attributes: bodyAttributes))
            if index < repeats - 1 {
                text.append(NSAttributedString(string: "\n\n", attributes: bodyAttributes))
            }
        }
        return text
    }
}

private struct ObstacleFullPage: View {
    let page: ObstaclePage
    let configuration: PreparedTextObstacleDemoConfiguration
    let language: PreparedTextDemoLanguage
    @Binding var touchRadius: Double
    @Binding var serpentSpeed: Double
    @Binding var bounceSpeed: Double

    init(
        page: ObstaclePage,
        configuration: PreparedTextObstacleDemoConfiguration,
        language: PreparedTextDemoLanguage,
        touchRadius: Binding<Double> = .constant(36),
        serpentSpeed: Binding<Double> = .constant(1.0),
        bounceSpeed: Binding<Double> = .constant(1.0)
    ) {
        self.page = page
        self.configuration = configuration
        self.language = language
        _touchRadius = touchRadius
        _serpentSpeed = serpentSpeed
        _bounceSpeed = bounceSpeed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(page.badge(language: language))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(page.title(language: language))
                        .font(.headline)
                }

                Spacer(minLength: 12)

                Text(page.trailingBadge(language: language))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PreparedObstaclePalette.chipBackground)
                    .clipShape(Capsule())
            }

            PreparedObstacleDemoSurface(configuration: configuration)
                .frame(height: 460)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(PreparedObstaclePalette.softStroke, lineWidth: 1)
                }

            Text(page.subtitle(language: language))
                .font(.caption)
                .foregroundStyle(.secondary)

            if page == .finger {
                HStack(spacing: 12) {
                    Text(controlLabel(for: page))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Slider(value: $touchRadius, in: 24...64, step: 1)

                    Text("\(Int(touchRadius)) pt")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
            } else if page == .bouncingBalls {
                HStack(spacing: 12) {
                    Text(controlLabel(for: page))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Slider(value: $bounceSpeed, in: 0.4...2.4, step: 0.1)

                    Text(String(format: "%.1fx", bounceSpeed))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
            } else {
                HStack(spacing: 12) {
                    Text(controlLabel(for: page))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Slider(value: $serpentSpeed, in: 0.4...2.2, step: 0.1)

                    Text(String(format: "%.1fx", serpentSpeed))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
            }
        }
        .padding(18)
        .background(PreparedObstaclePalette.panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PreparedObstaclePalette.softStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func controlLabel(for page: ObstaclePage) -> String {
        switch (language, page) {
        case (.english, .serpent):
            return "Serpent Speed"
        case (.english, .bouncingBalls):
            return "Bounce Speed"
        case (.english, .finger):
            return "Finger Halo"
        case (.korean, .serpent):
            return "용 속도"
        case (.korean, .bouncingBalls):
            return "공 속도"
        case (.korean, .finger):
            return "손가락 반경"
        case (.japanese, .serpent):
            return "ドラゴン速度"
        case (.japanese, .bouncingBalls):
            return "反射速度"
        case (.japanese, .finger):
            return "指ハロー"
        case (.chineseSimplified, .serpent):
            return "龙速度"
        case (.chineseSimplified, .bouncingBalls):
            return "弹跳速度"
        case (.chineseSimplified, .finger):
            return "手指光环"
        case (.chineseTraditional, .serpent):
            return "龍速度"
        case (.chineseTraditional, .bouncingBalls):
            return "彈跳速度"
        case (.chineseTraditional, .finger):
            return "手指光環"
        }
    }
}

private struct PreparedObstacleDemoSurface: UIViewRepresentable {
    let configuration: PreparedTextObstacleDemoConfiguration

    func makeUIView(context _: Context) -> PreparedTextObstacleDemoView {
        let view = PreparedTextObstacleDemoView()
        view.apply(configuration: configuration)
        return view
    }

    func updateUIView(_ uiView: PreparedTextObstacleDemoView, context _: Context) {
        uiView.apply(configuration: configuration)
    }
}

private enum ObstaclePage: String, CaseIterable, Identifiable, Hashable {
    case serpent
    case bouncingBalls
    case finger

    var id: String { rawValue }

    func shortTitle(language: PreparedTextDemoLanguage) -> String {
        switch (language, self) {
        case (.english, .serpent):
            return "Serpent"
        case (.english, .bouncingBalls):
            return "Bounce"
        case (.english, .finger):
            return "Finger"
        case (.korean, .serpent):
            return "용"
        case (.korean, .bouncingBalls):
            return "공"
        case (.korean, .finger):
            return "손가락"
        case (.japanese, .serpent):
            return "龍"
        case (.japanese, .bouncingBalls):
            return "球"
        case (.japanese, .finger):
            return "指"
        case (.chineseSimplified, .serpent):
            return "龙"
        case (.chineseSimplified, .bouncingBalls):
            return "弹球"
        case (.chineseSimplified, .finger):
            return "手指"
        case (.chineseTraditional, .serpent):
            return "龍"
        case (.chineseTraditional, .bouncingBalls):
            return "彈球"
        case (.chineseTraditional, .finger):
            return "手指"
        }
    }

    func title(language: PreparedTextDemoLanguage) -> String {
        switch (language, self) {
        case (.english, .serpent):
            return "Waving Serpent"
        case (.english, .bouncingBalls):
            return "Bouncing Orbs"
        case (.english, .finger):
            return "Finger Sweep"
        case (.korean, .serpent):
            return "흔들리는 용"
        case (.korean, .bouncingBalls):
            return "튀는 공들"
        case (.korean, .finger):
            return "손가락 스윕"
        case (.japanese, .serpent):
            return "うねる龍"
        case (.japanese, .bouncingBalls):
            return "跳ねる球"
        case (.japanese, .finger):
            return "指スイープ"
        case (.chineseSimplified, .serpent):
            return "摆动的龙"
        case (.chineseSimplified, .bouncingBalls):
            return "弹跳圆球"
        case (.chineseSimplified, .finger):
            return "手指扫动"
        case (.chineseTraditional, .serpent):
            return "擺動的龍"
        case (.chineseTraditional, .bouncingBalls):
            return "彈跳圓球"
        case (.chineseTraditional, .finger):
            return "手指掃動"
        }
    }

    func badge(language: PreparedTextDemoLanguage) -> String {
        switch (language, self) {
        case (.english, .serpent):
            return "AUTO PAGE"
        case (.english, .bouncingBalls):
            return "BOUNCE PAGE"
        case (.english, .finger):
            return "TOUCH PAGE"
        case (.korean, .serpent):
            return "자동 페이지"
        case (.korean, .bouncingBalls):
            return "바운스 페이지"
        case (.korean, .finger):
            return "터치 페이지"
        case (.japanese, .serpent):
            return "自動ページ"
        case (.japanese, .bouncingBalls):
            return "反射ページ"
        case (.japanese, .finger):
            return "タッチページ"
        case (.chineseSimplified, .serpent):
            return "自动页面"
        case (.chineseSimplified, .bouncingBalls):
            return "弹跳页面"
        case (.chineseSimplified, .finger):
            return "触摸页面"
        case (.chineseTraditional, .serpent):
            return "自動頁面"
        case (.chineseTraditional, .bouncingBalls):
            return "彈跳頁面"
        case (.chineseTraditional, .finger):
            return "觸控頁面"
        }
    }

    func trailingBadge(language: PreparedTextDemoLanguage) -> String {
        switch (language, self) {
        case (.english, .serpent):
            return "Glide"
        case (.english, .bouncingBalls):
            return "Bounce"
        case (.english, .finger):
            return "Drag"
        case (.korean, .serpent):
            return "활공"
        case (.korean, .bouncingBalls):
            return "반사"
        case (.korean, .finger):
            return "드래그"
        case (.japanese, .serpent):
            return "滑空"
        case (.japanese, .bouncingBalls):
            return "反射"
        case (.japanese, .finger):
            return "ドラッグ"
        case (.chineseSimplified, .serpent):
            return "滑行"
        case (.chineseSimplified, .bouncingBalls):
            return "弹跳"
        case (.chineseSimplified, .finger):
            return "拖动"
        case (.chineseTraditional, .serpent):
            return "滑行"
        case (.chineseTraditional, .bouncingBalls):
            return "彈跳"
        case (.chineseTraditional, .finger):
            return "拖曳"
        }
    }

    func subtitle(language: PreparedTextDemoLanguage) -> String {
        switch (language, self) {
        case (.english, .serpent):
            return "The long body now snakes through the page, with a tail that wags behind the head so the exclusion path feels like a living obstacle instead of a single circle."
        case (.english, .bouncingBalls):
            return "A cluster of round obstacles ricochets around the card like rubber balls, so the same prepared payload keeps reopening and reclosing narrow spans."
        case (.english, .finger):
            return "Drag across the page and the freshest points of the trail become temporary exclusion circles that fade away after the gesture."
        case (.korean, .serpent):
            return "길쭉한 몸통과 흔들리는 꼬리가 같이 움직여서, 하나의 원이 아니라 실제 장애물이 지나가는 느낌이 나도록 구성했습니다."
        case (.korean, .bouncingBalls):
            return "여러 원형 장애물이 탱탱볼처럼 안에서 튕겨 다녀서, 같은 prepared payload가 좁은 통로를 계속 다시 열고 닫는 모습을 보여줍니다."
        case (.korean, .finger):
            return "페이지를 드래그하면 최신 터치 지점이 잠시 장애물 원으로 바뀌고, 시간이 지나면 자연스럽게 사라집니다."
        case (.japanese, .serpent):
            return "長い胴体としなる尾が一緒に動くので、単一の円ではなく生きた障害物が流れていくように見えます。"
        case (.japanese, .bouncingBalls):
            return "複数の円形障害物がゴムボールのように跳ね返り、同じ prepared payload が細い通路を何度も開閉する様子を見せます。"
        case (.japanese, .finger):
            return "ページをドラッグすると最新の軌跡が一時的な除外円になり、しばらくすると自然に消えていきます。"
        case (.chineseSimplified, .serpent):
            return "长条身体和摆动尾巴一起移动，让避让效果看起来像真实生物经过，而不是单个圆形。"
        case (.chineseSimplified, .bouncingBalls):
            return "多个圆形障碍会像橡胶球一样在卡片里反弹，让同一份 prepared payload 不断重新打开和闭合狭窄通道。"
        case (.chineseSimplified, .finger):
            return "在页面上拖动后，最新轨迹会变成临时避让圆，并在短时间后自然淡出。"
        case (.chineseTraditional, .serpent):
            return "細長身體與擺動尾巴一起移動，讓避讓效果更像真實生物經過，而不是單一圓形。"
        case (.chineseTraditional, .bouncingBalls):
            return "多個圓形障礙會像橡膠球一樣在卡片裡反彈，讓同一份 prepared payload 不斷重新打開與關閉狹窄通道。"
        case (.chineseTraditional, .finger):
            return "在頁面上拖曳後，最新軌跡會變成暫時避讓圓，並在短時間後自然淡出。"
        }
    }
}

private struct ObstacleCopy {
    let title: String
    let detail: String
    let pickerTitle: String
    let serpentLead: String
    let serpentBody: String
    let bouncingLead: String
    let bouncingBody: String
    let fingerLead: String
    let fingerBody: String

    init(language: PreparedTextDemoLanguage) {
        switch language {
        case .english:
            title = "Obstacle Playground"
            detail = "This tab is now scrollable and more physical: one page shows a long dragon-like serpent with a wagging tail, one page bounces a cluster of rubber-ball obstacles, and the last keeps the finger trail test."
            pickerTitle = "Obstacle Page"
            serpentLead = "Waving serpent test page."
            serpentBody = " The payload is intentionally long and dense so the moving body can open several temporary gaps across multiple rows at once. Only the exclusion map changes while the same prepared payload keeps reflowing under the obstacle."
            bouncingLead = "Bouncing ball test page."
            bouncingBody = " Several round obstacles ricochet inside the card like rubber balls. The point is to watch the same prepared payload reopen tight channels over and over while the moving circles rebound off the text surface."
            fingerLead = "Finger trail test page."
            fingerBody = " Drag across the page and the surface turns the freshest parts of your path into temporary exclusion circles. Because the text occupies almost the whole page, a single sweep can carve out multiple bends and then settle back as the trail fades."
        case .korean:
            title = "장애물 플레이그라운드"
            detail = "이 탭은 이제 스크롤이 가능하고 더 물리적으로 보입니다. 한 페이지는 꼬리가 흔들리는 길쭉한 용을, 한 페이지는 탱탱볼처럼 튀는 공들을, 마지막 페이지는 손가락 궤적 테스트를 보여줍니다."
            pickerTitle = "장애물 페이지"
            serpentLead = "흔들리는 용 테스트 페이지."
            serpentBody = " 본문은 일부러 길고 촘촘하게 넣어서, 움직이는 몸통이 여러 줄에 동시에 빈 공간을 만들도록 했습니다. 바뀌는 것은 장애물 지도뿐이고, 같은 prepared payload가 계속 다시 흐릅니다."
            bouncingLead = "튀는 공 테스트 페이지."
            bouncingBody = " 여러 개의 원형 장애물이 카드 안에서 탱탱볼처럼 계속 튕깁니다. 움직이는 원들이 경계를 맞고 되돌아올 때마다 같은 prepared payload가 좁은 통로를 반복해서 열고 닫는 모습을 보는 용도입니다."
            fingerLead = "손가락 궤적 테스트 페이지."
            fingerBody = " 페이지를 드래그하면 가장 최근의 궤적이 잠시 장애물 원으로 바뀝니다. 텍스트가 거의 전체 면을 채우기 때문에 한 번의 스윕만으로도 여러 줄이 크게 휘었다가, 궤적이 사라지면서 원래 흐름으로 돌아갑니다."
        case .japanese:
            title = "障害物プレイグラウンド"
            detail = "このタブはスクロール可能になり、動きもより物理的になりました。片方は尾を振る長い龍、片方はゴムボールのように跳ねる球群、もう片方は指の軌跡テストです。"
            pickerTitle = "障害物ページ"
            serpentLead = "うねる龍のテストページ。"
            serpentBody = " 本文はあえて長く密にしてあり、動く胴体が複数の行にまたがって一時的な空洞を作るようにしています。変わるのは障害物マップだけで、同じ prepared payload が再び流れ続けます。"
            bouncingLead = "跳ねる球のテストページ。"
            bouncingBody = " 複数の円形障害物がカード内をゴムボールのように反射し続けます。円が境界に当たって戻るたびに、同じ prepared payload が細い通路を何度も開閉する様子を確認できます。"
            fingerLead = "指軌跡のテストページ。"
            fingerBody = " ページをドラッグすると最新の軌跡が一時的な除外円になり、広い本文面の中で複数行を同時に曲げたあと、軌跡の減衰とともに自然に元へ戻ります。"
        case .chineseSimplified:
            title = "障碍物实验场"
            detail = "这个标签现在可以滚动，并且运动更有实体感。一页展示带摆尾的长龙，一页展示像橡胶球一样反弹的圆球群，最后一页保留手指轨迹测试。"
            pickerTitle = "障碍页面"
            serpentLead = "摆动长龙测试页。"
            serpentBody = " 正文故意写得更长更密，让移动中的身体一次在多行上打开明显空隙。变化的只有障碍地图，同一份 prepared payload 会持续重新流动。"
            bouncingLead = "弹跳圆球测试页。"
            bouncingBody = " 多个圆形障碍会像橡胶球一样在卡片中不断反弹。圆球每次撞到边界再折返时，同一份 prepared payload 都会重新打开和闭合狭窄通道。"
            fingerLead = "手指轨迹测试页。"
            fingerBody = " 在页面上拖动后，最新轨迹会暂时变成避让圆。由于文本几乎铺满整张卡片，一次扫动就能让多行同时弯折，再随着轨迹淡出恢复原状。"
        case .chineseTraditional:
            title = "障礙物實驗場"
            detail = "這個分頁現在可以捲動，運動也更有實體感。一頁展示帶擺尾的長龍，一頁展示像橡膠球一樣反彈的圓球群，最後一頁保留手指軌跡測試。"
            pickerTitle = "障礙頁面"
            serpentLead = "擺動長龍測試頁。"
            serpentBody = " 內文刻意寫得更長更密，讓移動中的身體一次在多行上打開明顯空隙。改變的只有障礙地圖，同一份 prepared payload 會持續重新流動。"
            bouncingLead = "彈跳圓球測試頁。"
            bouncingBody = " 多個圓形障礙會像橡膠球一樣在卡片中不斷反彈。圓球每次撞到邊界再折返時，同一份 prepared payload 都會重新打開與關閉狹窄通道。"
            fingerLead = "手指軌跡測試頁。"
            fingerBody = " 在頁面上拖曳後，最新軌跡會暫時變成避讓圓。因為文字幾乎鋪滿整張卡片，一次掃動就能讓多行同時彎折，再隨著軌跡淡出恢復原狀。"
        }
    }
}
#endif
