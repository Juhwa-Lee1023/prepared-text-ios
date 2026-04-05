# Validation

prepared-text-ios ships two validation paths and one Apple-platform verification path.
The current host coverage locks down the stable release story through the latest engine-polish round:

- deterministic attributed-range cache identity
- width bucketization and pixel alignment behavior
- attachment-aware invalidation / placeholder reuse paths
- core-owned finite-line layout, truncation, and visible-range semantics
- layout-direction-sensitive alignment resolution
- public line-break strategy selection on supported narrow surfaces
- prepared token / annotation visibility through truncation-aware coordinate mapping
- explicit exact-vs-best-effort source/display mapping semantics
- coordinate-map rect queries that feed public link geometry and debug/inspection helpers
- public obstacle-layout helpers over prepared text on supported host/tooling builds
- geometry-packet vs draw-packet separation for measurement-heavy flows
- public truncation token/state helpers and visible-range reporting
- Stage 0 adoption diagnostics on supported UIKit paths
- focused URL/social-token validation for mid-line structured entry cases

## Host report

Use report mode to regenerate the human-readable validation artifact:

```bash
swift run PretextValidation --mode report
```

Or from the repo helper:

```bash
./scripts/run-validation.sh
```

This writes `.build/reports/validation-report.md`.

Report mode is intentionally descriptive. It prints the current host-side comparison report and semantic check results, but it does not fail on baseline diffs by itself.

The semantic check section now includes direct engine-level finite-line assertions such as:

- `finite-line-tail-truncation-is-core-owned`
- `single-line-tail-truncation-exposes-visible-range`
- `word-wrap-line-limit-still-reports-hidden-overflow`
- `url-friendly-line-limit-preserves-structured-breaks`
- `korean-finite-line-truncation-remains-core-owned`
- `layout-direction-affects-core-alignment-resolution`
- `geometry-packet-reuse-stays-separate-from-draw-cache`
- `custom-truncation-token-preserves-visible-range`
- `url-like-token-keeps-structured-breakpoint-after-mid-line-entry`
- `hashtag-prefers-delimiter-split-after-mid-line-entry`

Phase 3 semantic checks also run in the host validation path:

- `attachment-spans-report-placeholder-vs-resolved-state`
- `visible-tokens-follow-truncated-coordinate-map`
- `coordinate-map-best-effort-mode-is-explicit`
- `coordinate-map-rect-queries-follow-visible-link-geometry`
- `obstacle-layout-exposes-public-visible-structure`
- `rounded-rect-obstacle-layout-exposes-public-visible-structure`

UIKit-aware host validation also now checks Stage 0 rollout explanation on supported builds:

- `stage0-adoption-diagnostics-explain-finite-line-exclusion`

## Host gate

Use gate mode for release validation:

```bash
swift run PretextValidation --mode gate
```

Or from the repo helper:

```bash
./scripts/run-validation-gate.sh
```

Gate mode fails on any of the following within the stable host gate corpus:

- line-count mismatch
- first divergent line content
- height delta greater than `1pt`
- missing required baseline coverage

The host gate corpus covers the stable v1 release surface:

- `english-body`
- `url-basic`
- `mention-hashtag-basic`
- `nbsp`
- `soft-hyphen`
- `prewrap-tabs`
- `punctuation-heavy`
- `korean-body`
- `japanese-body`
- `arabic-body`

The remaining host fixtures are diagnostic-only:

- `mixed-bidi`
- `emoji-heavy`
- `mixed-runs`

## Apple-platform authority

The Apple-platform authority is the iOS simulator baseline path.
Run it before tagging:

```bash
./scripts/run-ios-demo-tests.sh
```

This path builds and tests the committed demo project and executes strict UIKit baselines through:

- `UILabelComparator`
- `UITextViewComparator`

The simulator baseline subset is intentionally narrower than the host stable corpus. It covers the core read-only UIKit release surface:

- `english-body`
- `url-basic`
- `mention-hashtag-basic`
- `nbsp`
- `prewrap-tabs`
- `soft-hyphen`

The simulator XCTest path also keeps the promoted UIKit-facing Phase 3 consumers honest:

- `PreparedLabelView` visible token / annotation / attachment helpers
- `PreparedLabelView` per-link accessibility elements for multi-link visible content, with safe fallback to container-level actions
- `PreparedTextObstacleLayouter` public result, coordinate-map, and visible-token helpers
- demo-backed read-only attachment and structured-span samples

The simulator XCTest path also covers Round 2 UIKit-facing utility surfaces:

- `PreparedLabelView.isTruncated()`, `visibleTextRange()`, and `visibleTextRanges()`
- `MeasurementCachingLabel().prepared(..., cacheProfile: ...)` and `PreparedLabelView().prepared(..., cacheProfile: ...)`
- `PreparedTextLegacySupport.adoptionDiagnostics(for:)` for stable Stage 0 exclusion reasons

## Release usage

For a release candidate or final tag, run:

```bash
swift build
swift test
swift run PretextValidation --mode report
swift run PretextValidation --mode gate
./scripts/run-ios-demo-tests.sh
```

Or use the combined helper:

```bash
./scripts/run-release-checks.sh
```

For performance verification, pair the validation gate with:

```bash
./scripts/run-benchmarks.sh
```

The benchmark report now compares exact widths with the public `balanced`, `aggressive`, and `stickyPrepared` cache profiles across Latin, Korean/CJK, emoji-heavy, long-token, attachment-inline, token-heavy, and long-text fixtures.
It also includes line-limited and URL-heavy scenarios so finite-line and mid-line structured-token behavior are exercised outside ad hoc UI tests, plus geometry-vs-draw packet rows, prepared-representation extraction rows, and obstacle-layout rows for the promoted public surfaces.
