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

## Phase 1 엔진 개선

Phase 1의 핵심은 이 라이브러리를 “얇은 텍스트 유틸리티”보다 “재사용 가능한 읽기 전용 레이아웃 엔진”에 가깝게 만드는 것입니다.

- cache identity 는 plain string 기준이 아니라 attributed range 변화까지 반영하는 deterministic layout key 로 정리됩니다
- inline attachment 가 측정에 영향을 주는 경우 attachment metric 도 layout identity 에 포함됩니다
- width normalization 은 `PreparedTextMeasurementOptions` 로 명시적으로 선택합니다
- pixel-aligned measurement 는 숨겨진 heuristic 이 아니라 public opt-in mode 입니다
- invalidation / background trim 은 `PreparedInvalidationCenter` 와 `PreparedTextSystem` 으로 명시적으로 제어합니다
- diagnostics 는 `PreparedTextSystem.diagnosticsSnapshot()` 으로 확인할 수 있습니다

예시:

```swift
let measurementOptions = PreparedTextMeasurementOptions(
    widthNormalizationPolicy: .bucketed(points: 4),
    pixelMeasurementPolicy: .alignedToScale
)

let label = MeasurementCachingLabel().prepared(
    sourceID: .init("feed/body"),
    measurementOptions: measurementOptions
)

let preparedView = PreparedLabelView().prepared(
    attributedText: NSAttributedString(string: "Prepared body copy"),
    sourceID: .init("feed/body"),
    measurementOptions: measurementOptions,
    maxLayoutWidth: 320
)

let diagnostics = PreparedTextSystem.shared.diagnosticsSnapshot()
PreparedInvalidationCenter.shared.trimForBackground()
```

width precision 이 실제 의미를 가지는 surface 라면 exact mode 를 사용하세요.
self-sizing loop 에서 비슷한 width proposal 이 반복되는 surface 라면 bucketed mode 가 맞습니다.
fractional width churn 때문에 measurement jitter 가 보인다면 pixel-aligned mode 를 같이 검토하세요.

## 개발

자주 쓰는 로컬 명령:

```bash
swift build
swift test
swift run PretextValidation --mode report
swift run PretextValidation --mode gate
swift run PretextBenchmarks
./scripts/run-ios-demo-tests.sh
./scripts/run-release-checks.sh
./scripts/check-repo-readiness.sh
```

이 저장소는 npm 의존성을 추가하지 않고 whylog scaffold만 얹어 둔 상태입니다:

```bash
npx --yes --package whylog@0.4.0 whylog doctor
npx --yes --package whylog@0.4.0 whylog commit -i
npx --yes --package whylog@0.4.0 whylog validate --range origin/main..HEAD --skip-unstructured --strict
```

`validate-whylog` workflow는 저장소가 structured trailer에 점진적으로 적응하는 동안 기존 GitHub Actions 체크와 분리해서 유지하고, on-demand fallback은 whylog `0.4.0` 으로 고정합니다.

maintainer / 릴리즈 문서:

- [Maintainers guide](docs/MAINTAINERS.md)
- [Versioning](docs/VERSIONING.md)
- [Releasing](docs/RELEASING.md)
- [Repository setup](docs/REPOSITORY_SETUP.md)
- [Validation](docs/Validation.md)
- [Benchmarks](docs/Benchmarks.md)
- [Migration guide](docs/MigrationGuide.md)
- [Known gaps](docs/KnownGaps.md)

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
