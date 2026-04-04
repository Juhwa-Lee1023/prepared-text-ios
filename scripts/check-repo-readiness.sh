#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

failures=0

record_failure() {
  echo "error: $*" >&2
  failures=1
}

exact_path_exists() {
  local path="$1"
  local parent child

  parent="$(dirname "$path")"
  child="$(basename "$path")"

  if [[ "$parent" == "." ]]; then
    find . -maxdepth 1 -mindepth 1 -name "$child" | grep -q .
  else
    find "$parent" -maxdepth 1 -mindepth 1 -name "$child" | grep -q .
  fi
}

search_tool=""

search_matches() {
  local pattern="$1"
  shift

  if [[ "$search_tool" == "rg" ]]; then
    rg -n "$pattern" "$@"
  else
    grep -nE "$pattern" "$@"
  fi
}

required_files=(
  README.md
  README.ko.md
  LICENSE
  CHANGELOG.md
  .gitignore
  .editorconfig
  .gitattributes
  CONTRIBUTING.md
  CODE_OF_CONDUCT.md
  SECURITY.md
  SUPPORT.md
  CODEOWNERS
  CITATION.cff
  .github/ISSUE_TEMPLATE/config.yml
  .github/ISSUE_TEMPLATE/bug_report.yml
  .github/ISSUE_TEMPLATE/feature_request.yml
  .github/ISSUE_TEMPLATE/docs_or_maintenance.yml
  .github/pull_request_template.md
  .github/labels.json
  .github/release.yml
  .github/workflows/ci.yml
  .github/workflows/pr-metadata.yml
  .github/workflows/release-check.yml
  .github/dependabot.yml
  scripts/check-pr.sh
  scripts/check-pr-metadata.py
  scripts/open-pr.sh
  scripts/create-tag.sh
  scripts/prepare-release.sh
  scripts/bootstrap-github.sh
  scripts/check-repo-readiness.sh
  scripts/run-tests.sh
  scripts/run-validation.sh
  scripts/run-validation-gate.sh
  scripts/run-benchmarks.sh
  scripts/run-ios-demo-tests.sh
  scripts/run-release-checks.sh
  docs/MAINTAINERS.md
  docs/RELEASING.md
  docs/VERSIONING.md
  docs/REPOSITORY_SETUP.md
  docs/Benchmarks.md
  docs/Validation.md
  docs/KnownGaps.md
  docs/MigrationGuide.md
  docs/ReleaseChecklist.md
  docs/assets/prepared-text-obstacle-demo-simulator.png
)

for path in "${required_files[@]}"; do
  [[ -e "$path" ]] || record_failure "Missing required file: $path"
done

for path in scripts/check-pr.sh scripts/open-pr.sh scripts/create-tag.sh scripts/prepare-release.sh scripts/bootstrap-github.sh scripts/check-repo-readiness.sh scripts/run-tests.sh scripts/run-validation.sh scripts/run-validation-gate.sh scripts/run-benchmarks.sh scripts/run-ios-demo-tests.sh scripts/run-release-checks.sh; do
  [[ -x "$path" ]] || record_failure "Expected executable script: $path"
done

grep -q '^# prepared-text-ios$' README.md || record_failure "README.md must title the repo as prepared-text-ios."
grep -q '^# prepared-text-ios$' README.ko.md || record_failure "README.ko.md must title the repo as prepared-text-ios."
grep -q 'README.ko.md' README.md || record_failure "README.md must link to README.ko.md."
grep -q 'README.md' README.ko.md || record_failure "README.ko.md must link back to README.md."
grep -q 'blank_issues_enabled: false' .github/ISSUE_TEMPLATE/config.yml || record_failure "Issue config must disable blank issues."
grep -q 'MIT' LICENSE || record_failure "LICENSE must contain MIT terms."
grep -q '^## \[Unreleased\]' CHANGELOG.md || record_failure "CHANGELOG.md must include an [Unreleased] section."
grep -q '^## \[0\.1\.0\]' CHANGELOG.md || record_failure "CHANGELOG.md must include an initial 0.1.0 section."
grep -q 'Semantic Versioning' docs/VERSIONING.md || record_failure "docs/VERSIONING.md must describe Semantic Versioning."
grep -q '^## Why this change exists$' .github/pull_request_template.md || record_failure ".github/pull_request_template.md must use the whylog PR heading."
grep -q '^Lore-id:' .github/pull_request_template.md || record_failure ".github/pull_request_template.md must include Lore-id."
grep -q 'whylog-style PR body template' CONTRIBUTING.md || record_failure "CONTRIBUTING.md must explain the whylog-style PR body template."
grep -q 'Prefer merge commits when the branch history is already small and coherent.' docs/MAINTAINERS.md || record_failure "docs/MAINTAINERS.md must describe the merge-commit preference."

python3 -m json.tool .github/labels.json >/dev/null || record_failure ".github/labels.json must be valid JSON."

if command -v rg >/dev/null 2>&1; then
  search_tool="rg"
elif command -v grep >/dev/null 2>&1; then
  search_tool="grep"
else
  record_failure "Either ripgrep (rg) or grep is required for placeholder and stale-slug readiness checks."
fi

public_text_files=(
  README.md
  README.ko.md
  CHANGELOG.md
  CONTRIBUTING.md
  CODE_OF_CONDUCT.md
  SECURITY.md
  SUPPORT.md
  CODEOWNERS
  CITATION.cff
  docs/MAINTAINERS.md
  docs/RELEASING.md
  docs/VERSIONING.md
  docs/REPOSITORY_SETUP.md
  .github/ISSUE_TEMPLATE/config.yml
  .github/ISSUE_TEMPLATE/bug_report.yml
  .github/ISSUE_TEMPLATE/feature_request.yml
  .github/ISSUE_TEMPLATE/docs_or_maintenance.yml
  .github/pull_request_template.md
  .github/workflows/ci.yml
  .github/workflows/pr-metadata.yml
  .github/workflows/release-check.yml
  .github/dependabot.yml
  Apps/PreparedTextDemo/README.md
  docs/Benchmarks.md
  docs/Validation.md
  docs/KnownGaps.md
  docs/MigrationGuide.md
  docs/ReleaseChecklist.md
)

if [[ -n "$search_tool" ]]; then
  if search_matches 'REPLACE_WITH_|TODO\(repo-setup\)|<OWNER>|<REPO>' "${public_text_files[@]}" >/dev/null; then
    search_matches 'REPLACE_WITH_|TODO\(repo-setup\)|<OWNER>|<REPO>' "${public_text_files[@]}" >&2
    record_failure "Found unresolved publication placeholders."
  fi

  if search_matches 'pretext_ios|prepared_text_ios' "${public_text_files[@]}" >/dev/null; then
    search_matches 'pretext_ios|prepared_text_ios' "${public_text_files[@]}" >&2
    record_failure "Found stale repository slug references."
  fi

  if search_matches 'Documentation/|Scripts/' "${public_text_files[@]}" >/dev/null; then
    search_matches 'Documentation/|Scripts/' "${public_text_files[@]}" >&2
    record_failure "Found stale legacy path references."
  fi

  if search_matches 'BenchmarkResults\.md|ValidationReport\.md|prepared-text-demo-video-[123]\.mp4|prepared-text-demo-simulator\.png' "${public_text_files[@]}" >/dev/null; then
    search_matches 'BenchmarkResults\.md|ValidationReport\.md|prepared-text-demo-video-[123]\.mp4|prepared-text-demo-simulator\.png' "${public_text_files[@]}" >&2
    record_failure "Found references to removed generated artifacts or excluded media."
  fi
fi

if [[ -d pretext_ios_prepare_layout_pack ]]; then
  record_failure "Found internal pretext_ios_prepare_layout_pack scaffolding. Remove it before the first public push."
fi

for path in Documentation Scripts docs/assets/prepared-text-demo-simulator.png docs/assets/prepared-text-demo-video-1.mp4 docs/assets/prepared-text-demo-video-2.mp4 docs/assets/prepared-text-demo-video-3.mp4 docs/BenchmarkResults.md docs/ValidationReport.md docs/DesignSummary.md; do
  exact_path_exists "$path" && record_failure "Found excluded path that should not exist in curated repo: $path"
done

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi

echo "Repository readiness checks passed."
