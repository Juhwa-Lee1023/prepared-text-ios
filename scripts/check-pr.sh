#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

title=""
body_file=""
event_json=""

usage() {
  cat <<'EOF'
Usage:
  ./scripts/check-pr.sh --title "fix(core): summary" --body-file /path/to/body.md
  ./scripts/check-pr.sh --event-json /path/to/pull_request_event.json
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
    --event-json)
      event_json="${2:-}"
      shift 2
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

if [[ -n "$event_json" ]]; then
  if [[ ! -f "$event_json" ]]; then
    echo "Error: --event-json does not exist or is not a regular file: $event_json" >&2
    exit 1
  fi

  if [[ ! -r "$event_json" ]]; then
    echo "Error: --event-json is not readable: $event_json" >&2
    exit 1
  fi

  python3 "$script_dir/check-pr-metadata.py" --event-json "$event_json"
  exit 0
fi

if [[ -z "$title" || -z "$body_file" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -f "$body_file" ]]; then
  echo "Error: --body-file does not exist or is not a regular file: $body_file" >&2
  exit 1
fi

if [[ ! -r "$body_file" ]]; then
  echo "Error: --body-file is not readable: $body_file" >&2
  exit 1
fi

python3 "$script_dir/check-pr-metadata.py" --title "$title" --body-file "$body_file"
