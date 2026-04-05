# Known Gaps

## Release Level

This repository is positioned as a **stable** library release for its documented narrow surface.

## Product Scope Limits

- `PreparedLabelView` and `PreparedTextView` are read-only multiline surfaces.
- The package does not implement editing, selection, caret movement, IME, or TextKit replacement behavior.
- UIKit-first adoption surfaces remain iOS-focused. macOS stays enabled for host-side `PretextCore`, validation, benchmark tooling, and narrow prepared-layout helpers such as obstacle-layout verification.
- Distribution is Swift Package Manager only.

## Layout And Baseline Limits

- Release validation is intentionally split:
  - host report mode keeps a Core Text proxy report in `.build/reports/validation-report.md`
  - host gate mode enforces the stable release corpus and fails on line-count, divergent-line, or height regressions
  - iOS simulator XCTest remains the Apple-platform authority through `UILabel` and `UITextView` baselines for the supported UIKit release subset
- The stable release corpus is narrower than broad browser-grade typography parity.
- Mixed bidi, emoji-heavy, and mixed attributed-run fixtures remain diagnostic coverage rather than a promise of browser-grade line-breaking parity.
- The library does not claim kinsoku-quality CJK handling, browser-grade punctuation rules, or full bidi shaping parity with every system text surface.

## Surface Limits

- Finite-line semantics are now core-owned through `PreparedTextLayoutOptions`, but the package still does not claim full `UILabel` or browser-grade paragraph behavior.
- `PreparedLabelView` supports line limits, truncation, alignment, line-break strategy selection, and read-only link activation, but it is still not a full `UILabel` replacement.
- The promoted `PreparedTextLayoutOptions` surface intentionally covers line limits, truncation, alignment, line-break strategy, and layout direction only. It is not a full paragraph layout or editing framework.
- `PreparedToken`, `PreparedAnnotation`, and `PreparedAttachmentSpan` are narrow inspection surfaces for read-only prepared content. They are not a syntax highlighting system, generalized parser, or authoring-time annotation model.
- `PreparedLabelView` now promotes multiple visible links to distinct accessibility elements when the prepared coordinate map can form stable visible rects. Container-level custom actions remain as a fallback when safe per-link geometry cannot be produced.
- `PreparedTextView` is a UIKit bridge. It does not replace native SwiftUI `Text` internals.
- `UILabel().prepared()` and global legacy UILabel support are Stage 0 sizing helpers only. They do not swap UILabel drawing for the Stage 1 renderer.
- `PreparedTextLegacySupport.installUILabelSupport(...)` should be treated as a main-thread app setup step. It is explicit runtime adoption, not import-time behavior.
- `.legacyMultiline` automatic rollout is intentionally narrower than “every multiline label”: finite line-limited truncating labels stay on system sizing semantics unless they are explicitly opted in.
- UILabel subclasses that heavily override sizing behavior may not automatically benefit from the base-class swizzled Stage 0 adoption path.
- Zero-argument `Text.prepared()` is intentionally unsupported. The package does not introspect native SwiftUI `Text`.
- Experimental `Text.prepared(source:)` is syntax sugar only: the explicit `source` payload is authoritative, and existing `Text` modifiers are not automatically preserved.
- `PreparedTextObstacleLayouter` is intentionally narrow: it handles repeated-width prepared text with circle and rounded-rect exclusion zones through `PreparedObstacleShape`. It is not a generalized obstacle or magazine-style flow layout engine.

## Cache And Runtime Limits

- Stage 0 and Stage 1 caches are bounded and trimmed for UIKit memory pressure, but they are tuned for read-mostly UI, not document editors.
- Performance claims are scoped to repeated-width read-only sizing workloads. Always benchmark inside the adopting app.
- Attachment identity, placeholder metrics, and resolved metrics now participate in prepared layout reuse through `PreparedAttachmentResolver`, but the repository still does not ship a full async attachment loader / placeholder renderer pipeline or remote media stack.
- `PreparedTextSourceCoordinateMap` now powers public visible token / annotation / attachment queries and rect helpers, but it is still not a full editor coordinate model and can fall back to best-effort mapping when whitespace normalization changes source/display correspondence.
- Signpost instrumentation exists for hot paths, but it is still lightweight profiling support rather than a complete tracing product.
- The demo app and showcase surfaces are verification tools for release readiness; they are not a second product surface.
- The public line-break strategy surface is intentionally narrow. It offers stable selection among supported heuristics, not generalized browser-grade typography control.
