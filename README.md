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

## Development

Useful local commands:

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

Maintainer and release docs:

- [Maintainers guide](docs/MAINTAINERS.md)
- [Versioning](docs/VERSIONING.md)
- [Releasing](docs/RELEASING.md)
- [Repository setup](docs/REPOSITORY_SETUP.md)
- [Validation](docs/Validation.md)
- [Benchmarks](docs/Benchmarks.md)
- [Known gaps](docs/KnownGaps.md)

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
