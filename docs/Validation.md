# Validation

prepared-text-ios ships two validation paths and one Apple-platform verification path.
Phase 1 also expects the benchmark runner to be part of release discipline because cache reuse and repeated-width behavior are now part of the public performance story.

## Host report

Use report mode to generate the human-readable validation report:

```bash
swift run PretextValidation --mode report
```

Or from the repo helper:

```bash
./scripts/run-validation.sh
```

The helper writes to `.build/reports/validation-report.md` by default.
Override the output path with `PRETEXT_VALIDATION_OUTPUT` if you need to store the report elsewhere locally.

Report mode is intentionally descriptive. It prints the current host-side comparison report and semantic check results, but it does not fail on baseline diffs by itself.

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
swift run PretextBenchmarks
./scripts/run-ios-demo-tests.sh
```

Or use the combined helper:

```bash
./scripts/run-release-checks.sh
```

Review the validation output together with the benchmark report. A clean release candidate should show:

- no stable-corpus gate regressions
- plausible repeated-width cache hit rates
- no obvious eviction explosions
- no suspicious attachment or CJK-only performance cliffs in the benchmark output
