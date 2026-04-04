#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
source "$script_dir/use-local-xcode.sh"

swift test "$@"
