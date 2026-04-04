# Validation

prepared-text-ios ships two validation paths and one Apple-platform verification path.
The current host coverage locks down the stable Phase 1 and Phase 2 release story:

- deterministic attributed-range cache identity
- width bucketization and pixel alignment behavior
- attachment-aware invalidation / placeholder reuse paths
- core-owned finite-line layout, truncation, and visible-range semantics
- layout-direction-sensitive alignment resolution
- public line-break strategy selection on supported narrow surfaces

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
- `word-wrap-line-limit-still-reports-hidden-overflow`
- `layout-direction-affects-core-alignment-resolution`

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

The benchmark report now compares exact widths, 4pt bucketed widths, and pixel-aligned measurement across Latin, Korean/CJK, emoji-heavy, long-token, attachment-inline, and long-text fixtures.
It also includes line-limited and URL-heavy scenarios so Phase 2 finite-line behavior is exercised outside ad hoc UI tests.
