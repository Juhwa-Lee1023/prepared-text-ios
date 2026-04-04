# Known Gaps

## Release Level

This repository is positioned as a **stable** library release for its documented narrow surface.

## Product Scope Limits

- `PreparedLabelView` and `PreparedTextView` are read-only multiline surfaces.
- The package does not implement editing, selection, caret movement, IME, or TextKit replacement behavior.
- Public UIKit and SwiftUI modules are iOS-only. macOS remains enabled for host-side `PretextCore`, validation, and benchmark tooling.
- Distribution is Swift Package Manager only.

## Layout And Baseline Limits

- Release validation is intentionally split:
  - host report mode keeps a Core Text proxy report in `.build/reports/validation-report.md` by default
  - host gate mode enforces the stable release corpus and fails on line-count, divergent-line, or height regressions
  - iOS simulator XCTest remains the Apple-platform authority through `UILabel` and `UITextView` baselines for the supported UIKit release subset
- The stable release corpus is narrower than broad browser-grade typography parity.
- Mixed bidi, emoji-heavy, and mixed attributed-run fixtures remain diagnostic coverage rather than a promise of browser-grade line-breaking parity.
- The library does not claim kinsoku-quality CJK handling, browser-grade punctuation rules, or full bidi shaping parity with every system text surface.

## Surface Limits

- `PreparedLabelView` supports line limits, truncation, alignment, and read-only link activation, but it is still not a full `UILabel` replacement.
- Link accessibility is exposed for read-only content, but multiple links inside one label are surfaced as custom accessibility actions rather than distinct accessibility elements.
- `PreparedTextView` is a UIKit bridge. It does not replace native SwiftUI `Text` internals.
- `UILabel().prepared()` and global legacy UILabel support are Stage 0 sizing helpers only. They do not swap UILabel drawing for the Stage 1 renderer.
- `PreparedTextLegacySupport.installUILabelSupport(...)` should be treated as a main-thread app setup step. It is explicit runtime adoption, not import-time behavior.
- `.legacyMultiline` automatic rollout is intentionally narrower than “every multiline label”: finite line-limited truncating labels stay on system sizing semantics unless they are explicitly opted in.
- UILabel subclasses that heavily override sizing behavior may not automatically benefit from the base-class swizzled Stage 0 adoption path.
- Zero-argument `Text.prepared()` is intentionally unsupported. The package does not introspect native SwiftUI `Text`.
- Experimental `Text.prepared(source:)` is syntax sugar only: the explicit `source` payload is authoritative, and existing `Text` modifiers are not automatically preserved.

## Cache And Runtime Limits

- Stage 0 and Stage 1 caches are bounded and trimmed for UIKit memory pressure, but they are tuned for read-mostly UI, not document editors.
- Performance claims are scoped to repeated-width read-only sizing workloads. Always benchmark inside the adopting app.
- The demo app and showcase surfaces are verification tools for release readiness; they are not a second product surface.
