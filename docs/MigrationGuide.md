# Migration Guide

## When To Use Prepared Text

아래 케이스는 custom prepared engine 으로 옮기기 좋다.

- chat bubble body text
- feed card body / summary
- list row secondary multiline text
- badge / card / capsule 안의 read-only multiline text
- prefetch 가능한 height prediction path

## Platform Note

- public UI migration target 은 iOS 전용이다.
- macOS 쪽 `swift test`, `PretextValidation`, `PretextBenchmarks` 는 host-side 개발 도구 경로로만 유지한다.
- 즉, surface migration 은 `PreparedLabelView` / `PreparedTextView` 기준으로 iOS 에서만 진행한다.

## When To Stay On System Controls

아래 케이스는 system text control 을 유지한다.

- editor
- compose field
- selection-heavy article reader
- IME / caret / rich editing surface
- Writing Tools / text interaction 을 그대로 가져가야 하는 화면

## Replacement Path

1. 먼저 Stage 0 경로부터 넣는다. 가장 보수적인 전역 rollout 은 main thread 에서 `PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)` 를 호출하는 것이다.
2. 특정 legacy label 부터 시작할 때는 `UILabel().prepared()` 또는 `UILabel().prepared(sourceID: .init("feed/body"))` 로 opt-in 한다.
3. 커스텀 타입을 직접 도입할 수 있으면 `MeasurementCachingLabel().prepared(sourceID: ...)` 를 사용한다.
4. Stage 1 로 올릴 surface 는 `PreparedLabelView().prepared(...)`, `PreparedTextView`, `PreparedCopy` 같은 explicit surface 로 연결하되, read-only multiline copy 에만 한정한다.
5. 기본 whitespace contract 는 `.uikitLiteral` 로 둔다. CSS-like collapse 가 필요할 때만 `.cssNormal`, preserved whitespace 가 필요할 때만 `.preWrap` 를 opt-in 한다.
6. width churn 이 심한 self-sizing loop 면 `PreparedTextMeasurementOptions(widthNormalizationPolicy: .bucketed(points: 4))` 같은 bucketed policy 를 먼저 검토한다. visual parity 가 더 중요하면 `.exactPixels` 를 유지한다.
7. fractional proposal jitter 가 반복 측정 흔들림을 만들면 `PreparedTextMeasurementOptions(pixelMeasurementPolicy: .alignedToScale)` 를 사용한다.
8. Stage 1 surface 에는 `PreparedTextLayoutOptions` 를 같이 도입해 line limit, truncation, alignment, line-break strategy, layout direction 을 view-local hack 이 아니라 core-owned explicit policy 로 다룬다.
9. stable SwiftUI sugar 는 `"Hello".prepared()`, `AttributedString("Hello").prepared()`, `NSAttributedString(...).prepared()` 처럼 명시적 payload 에만 쓴다.
10. zero-arg `Text.prepared()` 는 지원하지 않는다. native SwiftUI `Text` 는 public API 만으로 prepared-text pipeline 으로 정직하게 변환할 수 없기 때문이다.
11. ergonomic call-site syntax 가 꼭 필요하면 experimental `Text.prepared(source:)` 만 제한적으로 쓴다. 이때도 prepared renderer 는 `source` payload 를 authoritative input 으로 사용하고, 원래 `Text` modifier 는 자동으로 보존되지 않는다.
12. `.legacyMultiline` 는 unlimited multiline UILabel 을 자동 도입하지만 interactive label, attributed link label, finite line limit truncation label 은 기본적으로 제외한다.
13. attachment 크기가 늦게 확정되는 surface 면 `PreparedAttachmentRegistry` 와 `PreparedTextAttachment` 로 placeholder bounds 를 먼저 넣고, metrics 확정 후 targeted invalidation 을 걸어준다.
14. visible link, mention, hashtag, attachment span inspection 이 필요하면 prepared 결과에서 `PreparedText.tokens`, `PreparedText.annotations`, `PreparedText.attachmentSpans` 또는 packet의 `visibleTokens(in:)`, `visibleAnnotations(in:)`, `visibleAttachmentSpans(in:)` 를 사용한다.
15. source/display 대응이 필요한 UI 라면 `packet.sourceCoordinateMap` 을 기준으로 source range -> displayed span / line 변환을 한다. 단, `.cssNormal` 같은 whitespace normalization 경로에서는 reverse mapping 이 `.bestEffort` 일 수 있다는 점을 같이 반영한다.
16. avatar avoidance 나 decorative exclusion zone 이 필요하면 `PreparedTextObstacleLayouter` 를 쓰되, 현재 public scope 는 circle-only exclusion layout 이라는 점을 전제로 둔다.
17. 실제 화면 전환 전 `./scripts/run-tests.sh`, `./scripts/run-validation.sh`, `./scripts/run-benchmarks.sh`, `./scripts/run-ios-demo-tests.sh` 로 regression 을 확인한다.
18. committed `Apps/PreparedTextDemo/PreparedTextDemo.xcodeproj` 를 열어 chat/feed/list/card, table, collection self-sizing 경로와 prepared structure showcase / obstacle demo 를 확인한다.

## Do Not Migrate Yet

- general-purpose `UILabel` replacement
- rich attributed document viewer
- full text interaction / custom accessibility element 분할이 필요한 링크 surface
- bidi / CJK correctness 가 핵심인 surface
- arbitrary SwiftUI `Text` conversion
