#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
source "$script_dir/use-local-xcode.sh"

configuration="${PRETEXT_BENCH_CONFIGURATION:-release}"
output_path="${PRETEXT_BENCH_OUTPUT:-.build/reports/benchmark-results.md}"

mkdir -p "$(dirname "$output_path")"

swift build -c "$configuration" >/dev/null
swift run -c "$configuration" --skip-build PretextBenchmarks | tee "$output_path"

if [[ ! -s "$output_path" ]]; then
  echo "Benchmark report was not written to $output_path" >&2
  exit 1
fi
