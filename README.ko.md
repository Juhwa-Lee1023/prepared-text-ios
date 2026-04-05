[English](README.md) · [기여 안내](CONTRIBUTING.md) · [보안](SECURITY.md) · [라이선스](LICENSE)

# prepared-text-ios

너비 제안이 반복적으로 바뀌는 읽기 전용 텍스트 UI를 위한 Apple 플랫폼용 prepared-text 레이아웃 저장소입니다.

## 이 프로젝트가 하는 일

`prepared-text-ios`는 Apple 플랫폼에서 좁고 정직한 prepared-text 파이프라인을 공개 저장소로 정리한 프로젝트입니다.
기존 `PretextCore`, `PretextUIKit`, `PretextSwiftUI` 모듈을 `prepare -> layout -> draw` 모델 위에서 유지합니다.

주요 대상 surface는 다음과 같습니다.

- 채팅 버블
- 피드 카드
- 리스트 행
- 요약 블록
- self-sizing table / collection 콘텐츠
- 반복적인 width negotiation과 height prediction

## 이 프로젝트가 하지 않는 일

이 프로젝트는 다음을 목표로 하지 않습니다.

- 리치 텍스트 편집기
- selection / caret / IME 시스템
- 완전한 `UILabel` 호환 레이어
- 브라우저급 line breaking 엔진
- TextKit 대체재

광범위한 UIKit parity나 편집 워크플로가 필요하다면 시스템 텍스트 스택을 직접 사용하는 것이 맞습니다.

## 설치

### Swift Package Manager

```swift
.package(url: "https://github.com/Juhwa-Lee1023/prepared-text-ios.git", branch: "main")
```

첫 공개 릴리즈 태그가 올라간 뒤에는 `from: "0.1.0"` 같은 SemVer 태그 사용으로 전환하세요.

필요한 제품:

- `PretextCore`
- `PretextUIKit`
- `PretextSwiftUI`

## 빠른 시작

### UIKit

```swift
import UIKit
import PretextUIKit

PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)

let legacyLabel = UILabel().prepared()
legacyLabel.attributedText = NSAttributedString(string: "Prepared body copy")

let stage0Label = MeasurementCachingLabel().prepared(sourceID: .init("feed/body"))
stage0Label.attributedText = NSAttributedString(string: "Prepared body copy")

let label = PreparedLabelView().prepared(
    attributedText: NSAttributedString(string: "Prepared body copy"),
    sourceID: .init("feed/body"),
    maxLayoutWidth: 320,
    numberOfLines: 0
)
```

### SwiftUI

```swift
import SwiftUI
import PretextSwiftUI

struct FeedBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            "Hello".prepared()
            AttributedString("Hello").prepared()
            NSAttributedString(string: "Hello").prepared()
            PreparedCopy("Hello", maxLayoutWidth: 320)
        }
    }
}
```

### Experimental `Text.prepared(source:)`

```swift
let raw = "Hello"

Text("Hello").prepared(source: "Hello")
Text(verbatim: raw).prepared(source: raw)
```

이 API는 convenience syntax를 위한 experimental wrapper일 뿐입니다.

중요한 점:

- `source` 인자가 실제 prepared renderer에 들어가는 authoritative payload입니다
- `Text` receiver 자체는 introspect하지 않습니다
- 원래 `Text`에 이미 적용된 modifier는 자동으로 보존되지 않습니다
- 안정적이고 명시적인 사용은 아래 경로를 우선 권장합니다:
  - `String.prepared()`
  - `AttributedString.prepared()`
  - `NSAttributedString.prepared()`
  - `PreparedCopy(...)`

zero-arg `Text.prepared()`는 여전히 지원하지 않습니다. SwiftUI `Text`는 public API 기준으로 opaque 타입이기 때문입니다.

## 지원 범위

공개 범위는 의도적으로 좁습니다.

- 읽기 전용 prepared text
- UIKit 우선 렌더링
- SwiftUI 브리지
- legacy UIKit 경로를 위한 Stage 0 measurement-cache 도입
- Stage 1 prepared layout / draw surface
- 릴리즈 검증을 위한 validation / benchmark tooling

실제 surface를 기준으로 보면:

- `PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)`는 broad legacy multiline label에 가장 안전한 Stage 0 rollout 경로입니다.
- `UILabel().prepared()`는 UILabel drawing은 유지한 채 Stage 0 measurement caching만 붙입니다.
- `MeasurementCachingLabel().prepared(sourceID: ...)`는 커스텀 label을 직접 고를 수 있을 때의 명시적인 Stage 0 경로입니다.
- `PreparedLabelView().prepared(...)`는 명시적인 Stage 1 UIKit renderer입니다.
- `PreparedCopy(...)`와 `PreparedTextView`는 명시적인 Stage 1 SwiftUI surface입니다.

현재 패키지 제품 이름은 그대로 유지됩니다.

- `PretextCore`
- `PretextUIKit`
- `PretextSwiftUI`
- `PretextValidation`
- `PretextBenchmarks`

## Phase 1 / Phase 2 / Phase 3 엔진 개선 사항

이 라이브러리는 이제 단순한 "text view wrapper"보다, 읽기 전용 repeated-width surface를 위한 reusable layout engine에 더 가깝게 동작합니다.

- Stage 0 / Stage 1 모두에서 attributed-range 기반의 deterministic cache identity
- `WidthNormalizationPolicy` 로 드러나는 explicit width normalization
- `PreparedTextMeasurementOptions` 로 제어하는 public pixel-aligned measurement
- `PreparedInvalidationCenter` 기반 explicit invalidation
- `PreparedTextDiagnosticsSnapshot` 기반 public diagnostics
- `PreparedAttachmentRegistry` 기반 attachment-aware inline prepared layout
- `PreparedTextLayoutOptions` 기반 core-owned finite-line display policy
- `PreparedTextLineBreakStrategy` 기반 public line-break strategy 선택
- `PreparedToken`, `PreparedAnnotation`, `PreparedAttachmentSpan` 기반 public prepared-structure inspection
- `PreparedTextSourceCoordinateMap` 기반 practical source/display coordinate conversion
- `PreparedTextObstacleLayouter`, `PreparedObstacle` 기반 reusable circle-obstacle layout

예시:

```swift
import PretextCore

let system = PreparedTextSystem.shared
let prepared = system.prepare(
    NSAttributedString(string: "Prepared body copy"),
    sourceID: .init("feed/body")
)

let measurementEnv = MeasurementEnv(
    scale: 2,
    contentSizeCategory: "large",
    measurementOptions: PreparedTextMeasurementOptions(
        widthNormalizationPolicy: .bucketed(points: 4),
        pixelMeasurementPolicy: .alignedToScale
    )
)
let layoutOptions = PreparedTextLayoutOptions(
    maximumNumberOfLines: 2,
    lineBreakMode: .truncateTail,
    lineBreakStrategy: .urlFriendly,
    alignment: .natural,
    layoutDirection: .leftToRight
)

let packet = system.layoutPacket(
    prepared,
    maxWidth: 320,
    lineHeight: prepared.defaultLineHeight,
    env: measurementEnv,
    options: layoutOptions
)
let diagnostics = system.diagnosticsSnapshot()
let coordinateMap = packet.sourceCoordinateMap
let tokens = packet.visibleTokens(in: prepared)
let annotations = packet.visibleAnnotations(in: prepared)
let attachmentSpans = packet.visibleAttachmentSpans(in: prepared)
```

visual parity가 더 중요하면 exact width를 유지하세요.
근접한 width proposal이 반복되는 self-sizing loop라면 약간의 over-measure를 감수하고 bucketed width를 쓰는 편이 낫습니다.
fractional width jitter 때문에 반복 측정이 흔들리면 pixel-aligned measurement를 고려하세요.
line-limited card, summary, feed row를 UIKit 전용 post-processing이 아니라 엔진 차원의 prepared layout 시나리오로 다루고 싶다면 `PreparedTextLayoutOptions` 를 사용하세요.

Phase 2에서는 core engine이 직접 아래 semantics를 소유합니다.

- `maximumNumberOfLines`
- truncation mode
- line-break strategy
- layout-direction-sensitive alignment resolution
- visible line count / visible source range
- truncation state / early-stop semantics

즉, 2-line tail-truncated feed card는 이제 UIKit 레이어에서 잘라내는 동작이 아니라, core engine 안에서 별도 key와 reuse story를 갖는 layout 시나리오가 됩니다.
`PreparedLabelView` 와 `PreparedTextView` 는 이 core 결과를 소비해 렌더링하는 얇은 surface로 남습니다.

Phase 3에서는 이 ownership model 위에 네 가지 narrow public differentiator를 올립니다.

- `PreparedAttachmentRegistry` 기반 attachment-aware prepared layout
- `PreparedText.tokens`, `PreparedText.annotations`, `PreparedText.attachmentSpans` 기반 prepared structure inspection
- `PreparedTextSourceCoordinateMap` 기반 source/display coordinate conversion
- `PreparedTextObstacleLayouter` 기반 circle-only exclusion layout

여기서 attachment 지원이 뜻하는 범위는 다음과 같습니다.

- read-only inline attachment가 실제 metric이 도착하기 전에도 placeholder bounds를 제공할 수 있다
- resolved metrics와 content identity가 prepared layout reuse에 참여한다
- registry update가 영향을 받은 prepared source ID만 targeted invalidation 할 수 있다
- Stage 1 renderer는 이 metric을 소비하지만, full async media framework를 제공한다고 주장하지 않는다

token / annotation surface 역시 의도적으로 좁게 유지합니다.

- link, mention, hashtag, attachment span, prepared word-like span을 deterministic 하게 검사할 수 있다
- truncation 이후 visible token / annotation filtering은 packet 또는 coordinate map helper로 수행할 수 있다
- editor model, syntax highlighter framework, generalized NLP/entity product로 넓히지 않는다

coordinate mapping도 exactness를 숨기지 않습니다.

- source coordinate space를 보존하는 모드에서는 `.exact`
- whitespace normalization이 들어가는 모드에서는 `.bestEffort`
- source UTF-16 range를 displayed span / visible line으로 보내고, 보존 가능한 범위에서 다시 source range로 되돌릴 수 있다

obstacle-aware layout도 명확히 narrow 합니다.

- `PreparedTextObstacleLayouter` 는 repeated-width read-only text를 circle exclusion zone 주변에 흐르게 하는 용도입니다
- avatar avoidance, decorative card surface, editorial accent 같은 케이스에 맞습니다
- arbitrary publication layout, scene-graph composition, browser-grade flowing text를 목표로 하지 않습니다

이 surface 들 역시 prepared representation을 더 쓸모 있게 만드는 기능일 뿐이며, 프로젝트를 broad text toolkit으로 바꾸려는 것이 아닙니다. 핵심 가치는 여전히 deterministic reuse, bounded cache, explicit invalidation, core-owned read-only display policy, practical prepared-structure inspection에 있습니다.

## 개발

자주 쓰는 로컬 명령:

```bash
swift build
swift test
swift run PretextValidation --mode report
swift run PretextValidation --mode gate
swift run PretextBenchmarks
./scripts/run-benchmarks.sh
./scripts/run-ios-demo-tests.sh
./scripts/run-release-checks.sh
./scripts/check-repo-readiness.sh
```

커밋 워크플로는 whylog를 scaffold-only 모드로 사용합니다:

```bash
npx --yes --package whylog@0.4.0 whylog doctor
npx --yes --package whylog@0.4.0 whylog commit -i
npx --yes --package whylog@0.4.0 whylog validate --range origin/main..HEAD --skip-unstructured --strict
```

maintainer / 릴리즈 문서:

- [Maintainers guide](docs/MAINTAINERS.md)
- [Versioning](docs/VERSIONING.md)
- [Releasing](docs/RELEASING.md)
- [Repository setup](docs/REPOSITORY_SETUP.md)

## 데모 앱

커밋된 데모 앱은 [Apps/PreparedTextDemo](Apps/PreparedTextDemo/README.md)에 있습니다.
실제 Apple 런타임에서 UIKit / SwiftUI 동작을 검증할 때 사용하세요.

### 데모 영상

아래 업로드된 attachment URL은 GitHub README에서 인라인 비디오 플레이어로 렌더링됩니다.

**데모 영상 1**

https://github.com/user-attachments/assets/bc20205d-6588-40bd-a09f-e42eb6b86198

**데모 영상 2**

https://github.com/user-attachments/assets/6b7f0ea1-25e1-4647-b8ce-ec12d37e5cb0

**데모 영상 3**

https://github.com/user-attachments/assets/cba8336d-6124-4513-905c-f708bacbc1b1

## 기여

Pull request를 열기 전에 [CONTRIBUTING.md](CONTRIBUTING.md)를 읽어 주세요.

## 보안

보안 취약점은 [SECURITY.md](SECURITY.md)의 절차에 따라 비공개로 신고해 주세요.

## 라이선스

이 저장소는 [MIT License](LICENSE)로 배포됩니다.
