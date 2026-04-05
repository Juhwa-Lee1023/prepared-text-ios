# Release Checklist

Run the combined release script from the repository root before tagging a release:

```bash
./scripts/run-release-checks.sh
```

If you need the expanded equivalent steps for local debugging, run:

```bash
swift build
swift test
swift run PretextValidation --mode report
swift run PretextValidation --mode gate
swift run PretextBenchmarks
./scripts/run-ios-demo-tests.sh
```

## Release Gate Expectations

- `swift build`
  - the Swift package must build cleanly
- `swift test`
  - package XCTest targets must pass
- `swift run PretextValidation --mode report`
  - `.build/reports/validation-report.md` must regenerate from the current code
- `swift run PretextValidation --mode gate`
  - semantic checks must pass
  - the stable host gate corpus must keep exact line counts, no divergent strict lines, and `heightDelta <= 1pt`
  - core-owned finite-line / truncation / layout-direction semantic checks must stay green
  - 1-line truncation, visible-range, URL-heavy finite-line, and Korean finite-line semantic checks must stay green
  - geometry-vs-draw separation checks must stay green
  - custom truncation token / visible-range checks must stay green
  - focused mid-line URL / hashtag structured-token checks must stay green
  - attachment placeholder/resolved-state, attachment-scoped invalidation, truncation-visible token filtering, and coordinate-map best-effort semantics must stay green
  - coordinate-map rect-query checks for visible link geometry must stay green
  - obstacle-layout public structure checks, including rounded-rect exclusion, must stay green on supported host/tooling builds
  - Stage 0 adoption diagnostics checks must stay green on supported UIKit builds
- `swift run PretextBenchmarks`
  - `.build/reports/benchmark-results.md` must regenerate and be non-empty
  - release review should use the default benchmark sample counts, not a reduced local smoke profile
  - review exact vs `balanced` vs `aggressive` vs `stickyPrepared` policy rows rather than only single cold timings
  - review finite-line and URL strategy rows because Phase 2 moved that policy into the core engine
  - review geometry-vs-draw packet rows because Round 2 separates measurement-first packet reuse from draw-ready materialization
  - review prepared representation extraction and obstacle-layout rows because Phase 3 promotes them into public differentiators
  - review attachment-inline rows and obstacle shape rows because Round 1 turns attachment lifecycle and narrow obstacle generalization into documented public features
- `./scripts/run-ios-demo-tests.sh`
  - the committed iOS demo project at `Apps/PreparedTextDemo/PreparedTextDemo.xcodeproj` must build and test on simulator
  - strict `UILabel` / `UITextView` baseline XCTest must pass for the supported simulator baseline subset
  - promoted Stage 1 layout options, source-coordinate mapping, token / annotation helpers, per-link accessibility elements, attachment helpers, public truncation hooks, cache-profile helpers, and public obstacle layouter tests must stay green

## Manual Review Before Tagging

Review these files for honesty and freshness:

- `README.md`
- `README.ko.md`
- `docs/Validation.md`
- local `.build/reports/validation-report.md` if regenerated during the release pass
- `docs/Benchmarks.md`
- local `.build/reports/benchmark-results.md` if regenerated during the release pass
- `docs/KnownGaps.md`
- `docs/MigrationGuide.md`
- `Apps/PreparedTextDemo/README.md`

## Stable Release Bar

Do not tag a stable release unless all of the following are true:

- package tests pass
- validation report and validation gate pass
- benchmark output regenerates successfully
- simulator baseline tests pass
- release docs still match observed behavior
- remaining limitations stay within the documented narrow surface
