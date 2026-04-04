#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
source "$script_dir/use-local-xcode.sh"

output_path="${PRETEXT_VALIDATION_OUTPUT:-.build/reports/validation-report.md}"

mkdir -p "$(dirname "$output_path")"

swift build >/dev/null
swift run --skip-build PretextValidation --report "$@" | tee "$output_path"

if [[ ! -s "$output_path" ]]; then
  echo "Validation report was not written to $output_path" >&2
  exit 1
fi
