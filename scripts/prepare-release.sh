#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

version=""
skip_clean_check="false"
skip_product_checks="false"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/prepare-release.sh --version 0.1.0 [--skip-clean-check] [--skip-product-checks]
EOF
}

working_tree_clean() {
  [[ -z "$(git status --porcelain)" ]]
}

normalize_version() {
  local raw="$1"
  raw="${raw#v}"
  if [[ ! "$raw" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid semantic version: $1" >&2
    exit 1
  fi
  printf '%s' "$raw"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="$(normalize_version "${2:-}")"
      shift 2
      ;;
    --skip-clean-check)
      skip_clean_check="true"
      shift
      ;;
    --skip-product-checks)
      skip_product_checks="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$version" ]]; then
  echo "--version is required." >&2
  usage >&2
  exit 1
fi

if [[ "$skip_clean_check" != "true" ]]; then
  if ! working_tree_clean; then
    echo "Working tree must be clean before preparing a release." >&2
    git status --short >&2
    exit 1
  fi
fi

"$script_dir/check-repo-readiness.sh"

grep -q "^## \\[$version\\]" CHANGELOG.md || {
  echo "CHANGELOG.md must include a section for $version." >&2
  exit 1
}

if git rev-parse "refs/tags/v$version" >/dev/null 2>&1; then
  echo "Tag v$version already exists." >&2
  exit 1
fi

if [[ "$skip_product_checks" != "true" ]]; then
  "$script_dir/run-release-checks.sh"
fi

if ! working_tree_clean; then
  echo "Release checks produced tracked file changes. Resolve them before tagging." >&2
  git status --short >&2
  exit 1
fi

echo "Release preparation checks passed for v$version."
