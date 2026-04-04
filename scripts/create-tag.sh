#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

version=""
dry_run="false"
push_tag="false"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/create-tag.sh --version 0.1.0 [--dry-run] [--push]
EOF
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
    --dry-run)
      dry_run="true"
      shift
      ;;
    --push)
      push_tag="true"
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

"$script_dir/prepare-release.sh" --version "$version"

tag="v$version"
message="Release $tag"

if [[ "$dry_run" == "true" ]]; then
  echo "Dry run:"
  echo "  git tag -a $tag -m \"$message\""
  if [[ "$push_tag" == "true" ]]; then
    echo "  git push origin $tag"
  fi
  exit 0
fi

git tag -a "$tag" -m "$message"

if [[ "$push_tag" == "true" ]]; then
  git push origin "$tag"
fi

echo "Created annotated tag $tag."
