# Benchmarks

prepared-text-ios keeps a host-side benchmark runner for the prepared-text hot paths that matter to the public release story:

- Stage 0 measurement caching
- core finite-line prepared layout reuse
- exact vs public cache-profile comparison (`balanced`, `aggressive`, `stickyPrepared`)
- pixel-aligned measurement jitter reduction inside those measurement profiles
- line-break strategy selection on line-limited surfaces
- Latin, Korean/CJK, emoji-heavy, token-heavy, long-token, attachment-inline, and long-text corpora
- list-style batch sizing with public layout options
- geometry-packet vs draw-packet cost on measurement-heavy flows
- prepared token / annotation extraction cost
- source/display coordinate-map query cost
- circle and rounded-rect obstacle-layout sweeps on top of prepared text

## Run

```bash
swift run PretextBenchmarks
```

Or use the helper:

```bash
./scripts/run-benchmarks.sh
```

The helper regenerates `.build/reports/benchmark-results.md` and fails if the artifact is empty.

The release benchmark artifact should be generated with the default runner settings.
Use environment overrides only for local smoke runs or turnaround-sensitive exploration.

Useful environment overrides:

```bash
PRETEXT_BENCH_ITERATIONS=12 \
PRETEXT_BENCH_SWEEP_REPETITIONS=6 \
PRETEXT_BENCH_LIST_ITEMS=120 \
PRETEXT_BENCH_LIST_BATCH_REPETITIONS=2 \
./scripts/run-benchmarks.sh
```

## Interpretation

These benchmarks run as a host-side SwiftPM CLI on macOS. They are useful for:

- relative regression detection
- repeated-width workload comparisons
- core-owned finite-line layout vs unlimited layout behavior
- exact vs `balanced` vs `aggressive` vs `stickyPrepared` profile comparisons
- URL-heavy policy comparisons through line-break strategy sweeps
- geometry-only vs draw-ready packet comparisons when the caller only needs size, line count, or visible-range state
- cache reuse sanity checks through hit rate and cache-cost indicators
- prepared representation extraction cost for token / annotation / coordinate-map queries
- obstacle-layout cost on repeated-width prepared text around circle and rounded-rect exclusion zones

They are not a replacement for profiling on the final iOS app or device.

Read the report with these rules:

- `balanced` is the recommended conservative preset for mixed list/card adoption
- `aggressive` and `stickyPrepared` intentionally trade more width coalescing for more reuse in repeated self-sizing loops
- pixel alignment still matters inside those presets, but it is not expected to win every timing row
- attachment-inline rows should stay in the corpus because cache identity must remain attachment-aware
- list-style batch rows matter more than single cold timings when judging adoption value
- line-limited rows matter because Phase 2 moved max-lines and truncation ownership into the core engine
- `url-friendly` and `native-typesetter` strategy rows are narrow supported policies, not browser-grade guarantees
- geometry rows should demonstrate separate measurement-first packet reuse without forcing draw-packet cache population; they may be similar to draw rows in latency because correctness can still require shared shaping work
- prepared representation rows should stay cheap enough for inspection, hit-testing scaffolding, and analytics-style queries on already prepared packets
- obstacle-layout rows are intentionally narrow and should be read as circle / rounded-rect exclusion layout costs, not as a general document-layout benchmark

## Release usage

Run the benchmark runner before tagging a release so the generated report matches the final code:

```bash
swift run PretextBenchmarks
```

Or:

```bash
./scripts/run-benchmarks.sh
```

For release review, do not rely on a reduced-sample local smoke report.
If you temporarily lower the sample counts locally, rerun the default command before merging or tagging.

Then review `.build/reports/benchmark-results.md` together with validation and simulator test results.
