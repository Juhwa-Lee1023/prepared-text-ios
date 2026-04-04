#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

owner="${GITHUB_REPO_OWNER:-}"
repo="prepared-text-ios"
visibility="private"
description="Prepared-text layout library for Apple platforms with UIKit and SwiftUI integrations."
homepage=""
topics="ios,swift,swift-package,uikit,swiftui,text-layout"
default_branch="main"
enable_discussions="false"
create_if_missing="false"
require_codeowner_review="true"
required_checks=("ci / build-and-test" "pr-metadata / validate-pr-metadata")

usage() {
  cat <<'EOF'
Usage:
  ./scripts/bootstrap-github.sh [options]

Options:
  --owner <owner>
  --repo <repo>
  --visibility <public|private|internal>
  --description <text>
  --homepage <url>
  --topics <comma-separated>
  --default-branch <branch>
  --enable-discussions
  --create-if-missing
  --disable-codeowner-review
  --required-check <name>   (repeatable)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)
      owner="${2:-}"
      shift 2
      ;;
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --visibility)
      visibility="${2:-}"
      shift 2
      ;;
    --description)
      description="${2:-}"
      shift 2
      ;;
    --homepage)
      homepage="${2:-}"
      shift 2
      ;;
    --topics)
      topics="${2:-}"
      shift 2
      ;;
    --default-branch)
      default_branch="${2:-}"
      shift 2
      ;;
    --enable-discussions)
      enable_discussions="true"
      shift
      ;;
    --create-if-missing)
      create_if_missing="true"
      shift
      ;;
    --disable-codeowner-review)
      require_codeowner_review="false"
      shift
      ;;
    --required-check)
      required_checks+=("${2:-}")
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

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh auth status failed. Run \`gh auth login\` first." >&2
  exit 1
fi

if [[ -z "$owner" ]]; then
  owner="$(gh api user --jq .login)"
fi

repo_full="$owner/$repo"

if ! gh repo view "$repo_full" >/dev/null 2>&1; then
  if [[ "$create_if_missing" == "true" ]]; then
    gh repo create "$repo_full" "--$visibility" --description "$description" --disable-wiki --enable-issues
  else
    echo "Repository $repo_full does not exist." >&2
    echo "Create it with:" >&2
    echo "  gh repo create $repo_full --$visibility --description \"$description\" --disable-wiki --enable-issues" >&2
    exit 1
  fi
fi

repo_url="https://github.com/$repo_full.git"
if git remote get-url origin >/dev/null 2>&1; then
  current_origin_url="$(git remote get-url origin)"
  if [[ "$current_origin_url" != "$repo_url" ]]; then
    echo "Existing origin remote does not match expected repository." >&2
    echo "  expected: $repo_url" >&2
    echo "  actual:   $current_origin_url" >&2
    echo "Please update the origin remote or remove it before re-running this script." >&2
    exit 1
  fi
else
  git remote add origin "$repo_url"
fi

gh api -X PATCH "repos/$repo_full" \
  -f "name=$repo" \
  -f "description=$description" \
  -f "homepage=$homepage" \
  -F "has_issues=true" \
  -F "has_projects=false" \
  -F "has_wiki=false" \
  -F "has_discussions=$enable_discussions" \
  -f "default_branch=$default_branch" >/dev/null

python3 - <<'PY' "$topics" "$repo_full"
import json
import subprocess
import sys

topics = [item.strip() for item in sys.argv[1].split(",") if item.strip()]
repo_full = sys.argv[2]

subprocess.run(
    [
        "gh",
        "api",
        "-X",
        "PUT",
        f"repos/{repo_full}/topics",
        "--input",
        "-",
    ],
    input=json.dumps({"names": topics}),
    text=True,
    check=True,
)
PY

python3 - <<'PY' "$repo_full" ".github/labels.json"
import json
import subprocess
import sys
from urllib.parse import quote

repo_full = sys.argv[1]
labels_path = sys.argv[2]

labels = json.load(open(labels_path))
existing_payload = subprocess.check_output(
    ["gh", "api", f"repos/{repo_full}/labels"],
    text=True,
)
existing = {item["name"] for item in json.loads(existing_payload)}

for label in labels:
    name = label["name"]
    color = label["color"]
    description = label["description"]
    encoded_name = quote(name, safe="")
    if name in existing:
        subprocess.run(
            [
                "gh",
                "api",
                "-X",
                "PATCH",
                f"repos/{repo_full}/labels/{encoded_name}",
                "-f",
                f"new_name={name}",
                "-f",
                f"color={color}",
                "-f",
                f"description={description}",
            ],
            check=True,
        )
    else:
        subprocess.run(
            [
                "gh",
                "api",
                "-X",
                "POST",
                f"repos/{repo_full}/labels",
                "-f",
                f"name={name}",
                "-f",
                f"color={color}",
                "-f",
                f"description={description}",
            ],
            check=True,
        )
PY

checks_json="$(python3 - <<'PY' "${required_checks[@]}"
import json
import sys
print(json.dumps(sys.argv[1:]))
PY
)"

protection_payload="$(
python3 - <<'PY' "$checks_json" "$require_codeowner_review"
import json
import sys

contexts = json.loads(sys.argv[1])
require_codeowner_reviews = sys.argv[2].lower() == "true"

payload = {
    "required_status_checks": {
        "strict": True,
        "contexts": contexts,
    },
    "enforce_admins": True,
    "required_pull_request_reviews": {
        "dismiss_stale_reviews": True,
        "require_code_owner_reviews": require_codeowner_reviews,
        "required_approving_review_count": 1,
    },
    "restrictions": None,
    "allow_force_pushes": False,
    "allow_deletions": False,
    "block_creations": False,
    "required_conversation_resolution": True,
}
print(json.dumps(payload))
PY
)"

if ! gh api "repos/$repo_full/branches/$default_branch" >/dev/null 2>&1; then
  echo "Repository bootstrap completed for $repo_full." >&2
  echo "Branch protection was not applied because '$default_branch' does not exist on the remote yet." >&2
  echo "Push the default branch first, then rerun this script to apply protection with these required checks:" >&2
  for check in "${required_checks[@]}"; do
    echo "  - $check" >&2
  done
  exit 0
fi

if ! gh api -X PUT "repos/$repo_full/branches/$default_branch/protection" --input - <<<"$protection_payload" >/dev/null 2>&1; then
  echo "Failed to apply branch protection automatically." >&2
  echo "You may need elevated repository permissions. Re-run after checking access." >&2
  exit 1
fi

echo "GitHub repository bootstrap completed for $repo_full."
