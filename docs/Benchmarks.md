# Benchmarks

prepared-text-ios keeps a host-side benchmark runner for the prepared-text hot paths that matter to the public release story:

- Stage 0 measurement caching
- Stage 1 promoted display layout reuse
- exact vs bucketed width normalization
- pixel-aligned measurement jitter reduction
- Latin, Korean/CJK, emoji-heavy, long-token, attachment-inline, and long-text corpora
- list-style batch sizing with public layout options

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
- exact vs bucketed vs pixel-aligned policy comparisons
- cache reuse sanity checks through hit rate and cache-cost indicators

They are not a replacement for profiling on the final iOS app or device.

Read the report with these rules:

- higher hit rates on `bucketed-4pt` are expected for nearby width sweeps
- `pixel-aligned` is about reducing fractional proposal jitter, not about winning every timing row
- attachment-inline rows should stay in the corpus because cache identity must remain attachment-aware
- list-style batch rows matter more than single cold timings when judging adoption value

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
