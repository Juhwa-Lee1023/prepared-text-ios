# Benchmarks

prepared-text-ios keeps a host-side benchmark runner for the prepared-text hot paths that matter to the public release story:

- Stage 0 measurement caching
- Stage 1 cold and warm prepare
- repeated width layout
- repeated `nextLine` walking
- list-style batch sizing

## Run

```bash
swift run PretextBenchmarks
```

Or use the helper:

```bash
./scripts/run-benchmarks.sh
```

The helper writes a local report to `.build/reports/benchmark-results.md` by default and fails if the output is empty.
Override the path with `PRETEXT_BENCH_OUTPUT` when you need to keep a local copy elsewhere.

## Interpretation

These benchmarks run as a host-side SwiftPM CLI on macOS. They are useful for:

- relative regression detection
- repeated-width workload comparisons
- cache reuse sanity checks

They are not a replacement for profiling on the final iOS app or device.

## Release usage

Run the benchmark runner before tagging a release:

```bash
./scripts/run-benchmarks.sh
```

Then review the generated local output together with validation and simulator test results.
