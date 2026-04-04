#!/bin/zsh

if [[ -n "${PRETEXT_XCODE_DEVELOPER_DIR:-}" ]]; then
  export DEVELOPER_DIR="$PRETEXT_XCODE_DEVELOPER_DIR"
elif [[ -z "${DEVELOPER_DIR:-}" ]]; then
  current_developer_dir="$(xcode-select -p 2>/dev/null || true)"
  default_xcode_dir="/Applications/Xcode.app/Contents/Developer"

  if [[ -d "$default_xcode_dir" ]] && [[ -z "$current_developer_dir" || "$current_developer_dir" == "/Library/Developer/CommandLineTools" ]]; then
    export DEVELOPER_DIR="$default_xcode_dir"
  fi
fi

if [[ -n "${DEVELOPER_DIR:-}" ]] && [[ -d "$DEVELOPER_DIR/usr/bin" ]]; then
  case ":$PATH:" in
    *":$DEVELOPER_DIR/usr/bin:"*) ;;
    *) export PATH="$DEVELOPER_DIR/usr/bin:$PATH" ;;
  esac
fi
