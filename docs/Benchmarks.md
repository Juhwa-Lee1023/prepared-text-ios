# Benchmarks

prepared-text-ios keeps a host-side benchmark runner for the prepared-text hot paths that matter to the public release story:

- Stage 0 measurement caching
- Stage 1 warm prepare and repeated-width layout reuse
- list-style batch sizing
- width normalization policy comparisons
- diagnostics snapshots for cache hit ratio, eviction count, cache cost, and layout reuse

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
- exact-vs-bucketed width policy comparisons
- pixel-aligned measurement comparisons
- cache reuse sanity checks
- verifying that diagnostics counters move in plausible directions

They are not a replacement for profiling on the final iOS app or device.

The current benchmark corpus intentionally includes:

- Latin body text
- Korean body text
- Japanese/CJK body text
- emoji-heavy copy
- pre-wrap content
- long unbroken tokens
- long scrolling text
- inline attachments where the host platform supports them

The report highlights:

- `p50` and `p95` latency
- cache hit rate
- eviction count
- current cache cost estimate
- layout packet reuse count
- average observed lines per layout

## Width Policy Guidance

- Use `exact` when per-width identity is semantically important.
- Use `bucketed-4pt` as the first conservative opt-in for self-sizing surfaces that revisit nearby widths.
- Use `bucketed-4pt-aligned` when fractional proposals are causing repeated measurement jitter and you want the most stable repeated-width path.

## Release usage

Run the benchmark runner before tagging a release:

```bash
./scripts/run-benchmarks.sh
```

Then review the generated local output together with validation and simulator test results.
Look for:

- hit-rate regressions in repeated-width sweeps
- unexpected eviction spikes
- bucketed policy wins that disappear on the realistic corpora
- attachment-bearing fixtures behaving materially worse than plain-text fixtures
