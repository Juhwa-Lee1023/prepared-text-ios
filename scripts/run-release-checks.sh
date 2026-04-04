#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
source "$script_dir/use-local-xcode.sh"

swift build

"$script_dir/run-tests.sh"
"$script_dir/run-validation.sh"
"$script_dir/run-validation-gate.sh"
"$script_dir/run-benchmarks.sh"
"$script_dir/run-ios-demo-tests.sh"
