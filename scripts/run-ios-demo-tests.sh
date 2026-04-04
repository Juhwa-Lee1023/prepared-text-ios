#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
source "$script_dir/use-local-xcode.sh"

project_dir="Apps/PreparedTextDemo"
project_path="$project_dir/PreparedTextDemo.xcodeproj"
scheme="PreparedTextDemo"
derived_data_path="$(mktemp -d "${TMPDIR:-/tmp}/pretext-ios-demo-tests.XXXXXX")"
created_device_id=""

cleanup() {
  if [[ -n "$created_device_id" ]]; then
    xcrun simctl shutdown "$created_device_id" >/dev/null 2>&1 || true
    xcrun simctl delete "$created_device_id" >/dev/null 2>&1 || true
  fi
  rm -rf "$derived_data_path"
}
trap cleanup EXIT

if [[ ! -d "$project_path" ]]; then
  echo "Expected committed demo project at $project_path" >&2
  echo "Open the repository again if the project was not checked out, or regenerate it before committing." >&2
  exit 1
fi

pick_available_device_id() {
  python3 <<'PY'
import json
import re
import subprocess
import sys

try:
    payload = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        text=True,
    )
except subprocess.CalledProcessError:
    sys.exit(1)

data = json.loads(payload).get("devices", {})

def runtime_rank(runtime_identifier: str) -> tuple[int, ...]:
    match = re.search(r"iOS-(\d+)(?:-(\d+))?(?:-(\d+))?$", runtime_identifier)
    if not match:
        return (0, 0, 0)
    parts = [int(part) if part is not None else 0 for part in match.groups()]
    return tuple(parts)

preferred_names = {
    "iPhone 16 Pro": 0,
    "iPhone 16": 1,
    "iPhone 15 Pro": 2,
    "iPhone 15": 3,
}

booted = []
available = []

for runtime_identifier, devices in data.items():
    if "iOS" not in runtime_identifier:
        continue
    for device in devices:
        if not device.get("isAvailable", False):
            continue
        name = device.get("name", "")
        if "iPhone" not in name:
            continue
        record = (
            runtime_rank(runtime_identifier),
            preferred_names.get(name, 99),
            name,
            device.get("udid", ""),
        )
        state = device.get("state", "")
        if state == "Booted":
            booted.append(record)
        else:
            available.append(record)

pool = booted or available
if not pool:
    sys.exit(1)

pool.sort(key=lambda record: (-record[0][0], -record[0][1], -record[0][2], record[1], record[2], record[3]))
print(pool[0][3])
PY
}

pick_runtime_identifier() {
  python3 <<'PY'
import json
import re
import subprocess
import sys

payload = subprocess.check_output(
    ["xcrun", "simctl", "list", "runtimes", "available", "--json"],
    text=True,
)
data = json.loads(payload).get("runtimes", [])

def runtime_rank(identifier: str) -> tuple[int, ...]:
    match = re.search(r"iOS-(\d+)(?:-(\d+))?(?:-(\d+))?$", identifier)
    if not match:
        return (0, 0, 0)
    return tuple(int(part) if part is not None else 0 for part in match.groups())

candidates = []
for runtime in data:
    if not runtime.get("isAvailable", False):
        continue
    identifier = runtime.get("identifier", "")
    if "SimRuntime.iOS-" not in identifier:
        continue
    candidates.append((runtime_rank(identifier), identifier))

if not candidates:
    sys.exit(1)

candidates.sort(key=lambda item: item[0], reverse=True)
print(candidates[0][1])
PY
}

pick_device_type_identifier() {
  python3 <<'PY'
import json
import subprocess
import sys

payload = subprocess.check_output(
    ["xcrun", "simctl", "list", "devicetypes", "--json"],
    text=True,
)
data = json.loads(payload).get("devicetypes", [])

preferred_names = [
    "iPhone 16 Pro",
    "iPhone 16",
    "iPhone 15 Pro",
    "iPhone 15",
]

def candidate_for_name(name: str):
    for device in data:
        if device.get("name") == name:
            return device.get("identifier", "")
    return ""

for preferred in preferred_names:
    candidate = candidate_for_name(preferred)
    if candidate:
        print(candidate)
        sys.exit(0)

for device in data:
    name = device.get("name", "")
    identifier = device.get("identifier", "")
    if "iPhone" in name and identifier:
        print(identifier)
        sys.exit(0)

sys.exit(1)
PY
}

extract_destination_device_id() {
  local destination="$1"
  if [[ "$destination" =~ id=([^,]+) ]]; then
    print -r -- "${match[1]}"
  fi
  return 0
}

boot_and_wait_for_device() {
  local device_id="$1"
  [[ -z "$device_id" ]] && return 0
  xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$device_id" -b
}

if [[ -n "${PRETEXT_IOS_DESTINATION:-}" ]]; then
  destination="$PRETEXT_IOS_DESTINATION"
  device_id="$(extract_destination_device_id "$destination")"
else
  device_id="$(pick_available_device_id || true)"

  if [[ -z "$device_id" ]]; then
    runtime_identifier="$(pick_runtime_identifier || true)"
    device_type_identifier="$(pick_device_type_identifier || true)"

    if [[ -z "$runtime_identifier" || -z "$device_type_identifier" ]]; then
      echo "No available iOS Simulator destination was found." >&2
      echo "Install an iOS simulator runtime in Xcode or set PRETEXT_IOS_DESTINATION manually." >&2
      exit 1
    fi

    created_device_id="$(
      xcrun simctl create "Pretext Demo iPhone" "$device_type_identifier" "$runtime_identifier" 2>/dev/null || true
    )"
    device_id="$created_device_id"
  fi

  if [[ -z "$device_id" ]]; then
    echo "No available iOS Simulator destination was found." >&2
    echo "Install an iOS simulator runtime in Xcode or set PRETEXT_IOS_DESTINATION manually." >&2
    exit 1
  fi

  destination="platform=iOS Simulator,id=$device_id"
fi

boot_and_wait_for_device "${device_id:-}"

common_args=(
  -project "$project_path"
  -scheme "$scheme"
  -destination "$destination"
  -destination-timeout 180
  -derivedDataPath "$derived_data_path"
  CODE_SIGNING_ALLOWED=NO
)

xcodebuild build-for-testing "${common_args[@]}"

run_tests_once() {
  xcodebuild test-without-building "${common_args[@]}"
}

if ! run_tests_once; then
  echo "xcodebuild test-without-building failed once; retrying after simulator reboot." >&2
  if [[ -n "${device_id:-}" ]]; then
    xcrun simctl shutdown "$device_id" >/dev/null 2>&1 || true
    boot_and_wait_for_device "$device_id"
  fi
  run_tests_once
fi
