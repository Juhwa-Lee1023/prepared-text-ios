[한국어](README.ko.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [License](LICENSE)

# prepared-text-ios

Prepared-text layout for Apple platforms, built for read-only text surfaces that are measured repeatedly under changing widths.

## What this project is

`prepared-text-ios` is an open-source repository for a narrow prepared-text pipeline on Apple platforms.
It packages the existing `PretextCore`, `PretextUIKit`, and `PretextSwiftUI` modules behind a clear `prepare -> layout -> draw` model.

The intended use cases are:

- chat bubbles
- feed cards
- list rows
- summary blocks
- self-sizing table and collection content
- repeated width negotiation and height prediction

## What this project is not

This project is not trying to be:

- a rich text editor
- a selection, caret, or IME system
- a full `UILabel` compatibility layer
- a browser-grade line breaking engine
- a TextKit replacement

If you need broad UIKit parity or editing workflows, use the system text stack directly.

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/Juhwa-Lee1023/prepared-text-ios.git", branch: "main")
```

Use a SemVer tag such as `from: "0.1.0"` after the first public release tag is published.

Add one or more of these products:

- `PretextCore`
- `PretextUIKit`
- `PretextSwiftUI`

## Quick start

### UIKit

```swift
import UIKit
import PretextUIKit

PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)

let legacyLabel = UILabel().prepared()
legacyLabel.attributedText = NSAttributedString(string: "Prepared body copy")
let adoption = PreparedTextLegacySupport.adoptionDiagnostics(for: legacyLabel)

let stage0Label = MeasurementCachingLabel().prepared(
    sourceID: .init("feed/body"),
    cacheProfile: .balanced
)
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

This API is experimental convenience syntax only.

Important:

- the `source` argument is authoritative
- the `Text` receiver is not introspected
- modifiers already applied to the original `Text` are not automatically preserved
- for stable and explicit usage, prefer:
  - `String.prepared()`
  - `AttributedString.prepared()`
  - `NSAttributedString.prepared()`
  - `PreparedCopy(...)`

Zero-argument `Text.prepared()` is still not supported because SwiftUI `Text` remains opaque through public API.

## Supported scope

The public scope is intentionally narrow:

- read-only prepared text
- UIKit-first rendering
- SwiftUI bridge
- Stage 0 measurement-cache adoption for legacy UIKit paths
- Stage 1 prepared layout and draw surfaces
- validation and benchmark tooling for release discipline

In practice:

- `PreparedTextLegacySupport.installUILabelSupport(.legacyMultiline)` enables the safest Stage 0 rollout for broad legacy multiline labels.
- `UILabel().prepared()` keeps UILabel drawing and opts the label into Stage 0 measurement caching.
- `MeasurementCachingLabel().prepared(sourceID: ...)` is the explicit Stage 0 path when you can choose a custom label class.
- `PreparedLabelView().prepared(...)` is the explicit Stage 1 UIKit renderer.
- `PreparedCopy(...)` and `PreparedTextView` are the explicit Stage 1 SwiftUI surfaces.

The package product names stay as they are today:

- `PretextCore`
- `PretextUIKit`
- `PretextSwiftUI`
- `PretextValidation`
- `PretextBenchmarks`

## Current engine improvements

The current library story is stronger than "a text view wrapper".
It now behaves like a reusable layout engine for read-only repeated-width surfaces:

- deterministic attributed-range cache identity for Stage 0 and Stage 1 reuse
- explicit width normalization through `WidthNormalizationPolicy`
- public pixel-aligned measurement through `PreparedTextMeasurementOptions`
- public cache profile presets through `PreparedTextCacheProfile`
- explicit invalidation through `PreparedInvalidationCenter`
- public diagnostics through `PreparedTextDiagnosticsSnapshot`
- attachment-aware inline prepared layout through `PreparedAttachmentResolver` and `PreparedAttachmentRegistry`
- core-owned finite-line display policy through `PreparedTextLayoutOptions`
- public line-break strategy selection through `PreparedTextLineBreakStrategy`
- public prepared-structure inspection through `PreparedToken`, `PreparedAnnotation`, and `PreparedAttachmentSpan`
- practical source/display conversion and rect queries through `PreparedTextSourceCoordinateMap`
- reusable circle / rounded-rect obstacle layout through `PreparedTextObstacleLayouter` and `PreparedObstacle`
- measurement-first geometry packets through `PreparedGeometryPacket`
- draw-ready packet materialization through `PreparedDrawPacket`
- public truncation hooks such as `PreparedTruncationToken`, `PreparedGeometryPacket.visibleTextRange`, and `PreparedLabelView.isTruncated()`
- Stage 0 rollout diagnostics through `PreparedTextLegacySupport.adoptionDiagnostics(for:)`

Example:

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

let geometry = system.geometryPacket(
    prepared,
    maxWidth: 320,
    lineHeight: prepared.defaultLineHeight,
    env: measurementEnv,
    options: layoutOptions
)
let visibleRange = geometry.visibleTextRange
let isTruncated = geometry.result.isTruncated

let packet = system.drawPacket(
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
let linkRects = annotations.first.map { coordinateMap.displayedRects(for: $0) } ?? []
```

Use exact widths when visual parity matters more than cache reuse.
Use `PreparedTextCacheProfile.balanced`, `.aggressive`, or `.stickyPrepared` when self-sizing loops keep probing nearby proposals and a controlled over-measure is acceptable.
Use pixel-aligned measurement when fractional width jitter is causing unstable repeated measurement.
Use `PreparedGeometryPacket` when size, visible range, line count, or truncation state are enough.
Use `PreparedDrawPacket` or `PreparedTextDisplayPacket` only when attributed lines, CTLine-backed drawing, or draw-ready rect geometry are actually needed.
Use `PreparedTextLayoutOptions` when a line-limited card, summary block, or feed row should be a first-class engine layout scenario rather than UIKit-only post-processing.

In Phase 2, the core engine itself owns:

- `maximumNumberOfLines`
- truncation mode
- line-break strategy
- layout-direction-sensitive alignment resolution
- visible line count and visible source range
- truncation state and early-stop semantics

That means a 2-line tail-truncated feed card now has its own prepared layout key and reuse behavior in the core engine.
`PreparedLabelView` and `PreparedTextView` consume that result for rendering instead of inventing truncation semantics on their own.

Phase 3 builds on that ownership model with four narrow public differentiators:

- attachment-aware prepared layout through placeholder metrics, resolved metrics, attachment identity, and targeted invalidation in `PreparedAttachmentResolver` / `PreparedAttachmentRegistry`
- prepared token and annotation inspection through `PreparedText.tokens`, `PreparedText.annotations`, and `PreparedText.attachmentSpans`
- source/display coordinate conversion and visible rect queries through `PreparedTextSourceCoordinateMap`
- per-link accessibility elements in `PreparedLabelView` when multiple visible links remain on screen
- circle and rounded-rect exclusion layout through `PreparedTextObstacleLayouter`

The current round deepens engine ownership without broadening the product:

- measurement-heavy flows can stop at `PreparedGeometryPacket` instead of always materializing draw packets
- public truncation hooks expose `isTruncated`, `visibleTextRange`, `visibleTextRanges`, and a narrow `PreparedTruncationToken` customization point
- `PreparedTextLineBreakStrategy.urlFriendly` now keeps delimiter-aware URL and social-token splits more often when a structured token begins mid-line
- Stage 0 adoption can be inspected through `PreparedTextLegacySupport.adoptionDiagnostics(for:)`, while `PreparedTextCacheProfile` keeps cache tuning public and conservative

This is still not an editor model, browser-grade line-break engine, or full `UILabel` replacement. The round is about making the prepared engine easier to adopt, measure, and inspect on read-only UIKit-first surfaces.

Attachment support now means:

- inline read-only attachments can contribute placeholder bounds before real metrics are available
- `PreparedAttachmentResolver` exposes the placeholder vs resolved lifecycle directly, while `PreparedAttachmentRegistry` remains the default shared adapter
- resolved metrics and content identity participate in prepared layout reuse
- registry updates can target only the affected prepared source IDs for invalidation
- Stage 1 renderers consume those resolved metrics without pretending to be a full async media framework

Token and annotation APIs are intentionally narrow:

- links, mentions, hashtags, attachment spans, and prepared word-like spans can be inspected deterministically
- visible token and annotation filtering works through the packet or coordinate map after truncation
- `PreparedTextSourceCoordinateMap.displayedRects(...)` can turn those ranges back into visible rects for interaction, analytics, debug overlays, and accessibility scaffolding
- the package still does not become an editor model, syntax highlighter framework, or generalized NLP/entity system

Coordinate mapping is also explicit about exactness:

- coordinate-preserving modes expose `.exact` mapping
- whitespace-normalizing modes expose `.bestEffort` mapping instead of pretending reverse conversion is perfect
- packet and map helpers can translate source UTF-16 ranges to displayed spans, visible lines, visible rects, and back where the prepared representation preserves enough information
- `PreparedLabelView` builds its multi-link accessibility geometry from that same prepared representation, and falls back to container-level custom actions only when separate visible elements cannot be formed safely

The public truncation surface stays narrow and renderer-facing:

- `PreparedTruncationToken` lets callers swap the visible token text and choose whether the token inherits visible-line attributes, tail-source attributes, or a plain neutral presentation
- `PreparedGeometryPacket.visibleTextRange` and `PreparedLayoutPacket.visibleTextRange` report visible source ranges without forcing an editor-like selection model
- `PreparedLabelView.isTruncated()`, `visibleTextRange()`, and `visibleTextRanges()` give UIKit callers a direct path for "read more", analytics, or debug overlays on already prepared content

Stage 0 adoption also stays explicit rather than magical:

- `PreparedTextLegacySupport.adoptionDiagnostics(for:)` explains whether a label used prepared measurement and why
- reasons stay stable and rollout-oriented, such as single-line exclusion, finite-line semantics requiring Stage 1, interactive exclusions, or attributed-link exclusions
- diagnostics are opt-in snapshots, not noisy production logging
- `PreparedTextCacheProfile` is a small preset layer over real measurement options, not a cosmetic enum

Obstacle-aware layout remains intentionally narrow:

- `PreparedTextObstacleLayouter` is for repeated-width read-only layout around circle or rounded-rect exclusion zones
- it fits card, avatar, and decorative avoidance scenarios
- it does not claim arbitrary publication layout, scene-graph composition, or browser-grade flowing text

These surfaces remain narrow prepared-representation features. They do not change the product story into a broad text toolkit, and the main value is still deterministic reuse, bounded caches, explicit invalidation, core-owned read-only display policy, and practical prepared-structure inspection.

## Development

Useful local commands:

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

Commit workflow uses whylog in scaffold-only mode:

```bash
npx --yes --package whylog@0.4.0 whylog doctor
npx --yes --package whylog@0.4.0 whylog commit -i
npx --yes --package whylog@0.4.0 whylog validate --range origin/main..HEAD --skip-unstructured --strict
```

Maintainer and release docs:

- [Maintainers guide](docs/MAINTAINERS.md)
- [Versioning](docs/VERSIONING.md)
- [Releasing](docs/RELEASING.md)
- [Repository setup](docs/REPOSITORY_SETUP.md)

## Demo app

The committed demo app lives in [Apps/PreparedTextDemo](Apps/PreparedTextDemo/README.md).
Use it to verify UIKit and SwiftUI behavior on Apple runtimes before shipping your own integration.

### Demo videos

GitHub renders the uploaded attachment URLs below as inline video players.

**Demo video 1**

https://github.com/user-attachments/assets/bc20205d-6588-40bd-a09f-e42eb6b86198

**Demo video 2**

https://github.com/user-attachments/assets/6b7f0ea1-25e1-4647-b8ce-ec12d37e5cb0

**Demo video 3**

https://github.com/user-attachments/assets/cba8336d-6124-4513-905c-f708bacbc1b1

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Security

Please follow [SECURITY.md](SECURITY.md) for private vulnerability reporting.

## License

This repository is released under the [MIT License](LICENSE).
