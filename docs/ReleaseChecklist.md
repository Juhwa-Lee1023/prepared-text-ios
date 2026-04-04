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
- `swift run PretextBenchmarks`
  - `.build/reports/benchmark-results.md` must regenerate and be non-empty
  - release review should use the default benchmark sample counts, not a reduced local smoke profile
  - review exact vs `bucketed-4pt` vs `pixel-aligned` policy rows rather than only single cold timings
- `./scripts/run-ios-demo-tests.sh`
  - the committed iOS demo project at `Apps/PreparedTextDemo/PreparedTextDemo.xcodeproj` must build and test on simulator
  - strict `UILabel` / `UITextView` baseline XCTest must pass for the supported simulator baseline subset
  - promoted Stage 1 layout options, source-coordinate mapping, and public obstacle layouter tests must stay green

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
