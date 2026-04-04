#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
template_path="$repo_root/.github/pull_request_template.md"

title=""
body_file=""
base_branch="main"
draft="false"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/open-pr.sh --title "fix(core): summary" [--body-file /path/to/body.md] [--base main] [--draft]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      title="${2:-}"
      shift 2
      ;;
    --body-file)
      body_file="${2:-}"
      shift 2
      ;;
    --base)
      base_branch="${2:-}"
      shift 2
      ;;
    --draft)
      draft="true"
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

if [[ -z "$title" ]]; then
  echo "--title is required." >&2
  usage >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required." >&2
  exit 1
fi

gh auth status >/dev/null

current_branch="$(git -C "$repo_root" branch --show-current)"
if [[ -z "$current_branch" || "$current_branch" == "main" ]]; then
  echo "Open a PR from a feature branch, not from main." >&2
  exit 1
fi

temp_body=""
cleanup() {
  if [[ -n "$temp_body" && -f "$temp_body" ]]; then
    rm -f "$temp_body"
  fi
}
trap cleanup EXIT

if [[ -z "$body_file" ]]; then
  temp_body="$(mktemp "${TMPDIR:-/tmp}/prepared-text-pr-body.XXXXXX")"
  mv "$temp_body" "$temp_body.md"
  temp_body="$temp_body.md"
  cp "$template_path" "$temp_body"
  "${EDITOR:-vi}" "$temp_body"
  body_file="$temp_body"
fi

"$script_dir/check-pr.sh" --title "$title" --body-file "$body_file"

cmd=(gh pr create --base "$base_branch" --title "$title" --body-file "$body_file")
if [[ "$draft" == "true" ]]; then
  cmd+=(--draft)
fi

(cd "$repo_root" && "${cmd[@]}")
