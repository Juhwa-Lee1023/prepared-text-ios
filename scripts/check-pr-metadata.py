#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


ALLOWED_TYPES = {
    "feat",
    "fix",
    "docs",
    "refactor",
    "perf",
    "test",
    "build",
    "ci",
    "chore",
    "release",
}

TITLE_PATTERN = re.compile(
    r"^(?P<type>feat|fix|docs|refactor|perf|test|build|ci|chore|release)(\([a-z0-9._/-]+\))?: .+\S$"
)

REQUIRED_SECTIONS = [
    "Summary",
    "Motivation",
    "Scope",
    "Screenshots / demo links",
    "Tests run",
    "Release notes",
    "Breaking changes",
    "Linked issues",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate pull request metadata.")
    parser.add_argument("--title", help="Pull request title")
    parser.add_argument("--body-file", help="Path to a file containing the PR body")
    parser.add_argument("--event-json", help="Path to a pull_request GitHub event payload")
    return parser.parse_args()


def load_from_event(path: str) -> tuple[str, str]:
    payload = json.loads(Path(path).read_text())
    pr = payload.get("pull_request", {})
    return (pr.get("title") or "", pr.get("body") or "")


def split_sections(body: str) -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    current: str | None = None

    for line in body.splitlines():
        heading = re.match(r"^##\s+(.+?)\s*$", line)
        if heading:
            current = heading.group(1).strip()
            sections[current] = []
            continue
        if current is not None:
            sections[current].append(line)

    return {key: "\n".join(value).strip() for key, value in sections.items()}


def looks_empty(value: str) -> bool:
    cleaned = value.strip()
    if cleaned in {"", "-", "TBD"}:
        return True

    normalized = re.sub(r"\s+", " ", cleaned)
    template_stubs = {
        "- In scope: - Out of scope:",
        "```bash # paste exact commands here ```",
    }
    if normalized in template_stubs:
        return True

    return False


def validate_title(title: str, errors: list[str]) -> None:
    if not title:
        errors.append("PR title is required.")
        return

    match = TITLE_PATTERN.match(title)
    if not match:
        errors.append(
            "PR title must match `type(scope): summary` with an allowed type: "
            + ", ".join(sorted(ALLOWED_TYPES))
        )
        return

    if match.group("type") not in ALLOWED_TYPES:
        errors.append(f"Unsupported PR type `{match.group('type')}`.")


def validate_body(body: str, errors: list[str]) -> None:
    if not body.strip():
        errors.append("PR body is required.")
        return

    sections = split_sections(body)

    for section in REQUIRED_SECTIONS:
        if section not in sections:
            errors.append(f"Missing required body section `## {section}`.")

    if errors:
        return

    for section in ["Summary", "Motivation", "Scope", "Tests run"]:
        if looks_empty(sections[section]):
            errors.append(f"`## {section}` must not be empty.")

    screenshots_value = sections["Screenshots / demo links"]
    if looks_empty(screenshots_value):
        errors.append(
            "`## Screenshots / demo links` must say `Not applicable.` or include links/screenshots."
        )

    breaking_changes = sections["Breaking changes"].strip()
    if breaking_changes in {"", "-", "TBD"}:
        errors.append("`## Breaking changes` must explain the impact or explicitly say `None.`")

    linked_issues = sections["Linked issues"]
    if not (
        re.search(r"#\d+", linked_issues)
        or re.search(r"\bno issue\b", linked_issues, re.IGNORECASE)
    ):
        errors.append("`## Linked issues` must include an issue reference like `#123` or `No issue.`")

    release_notes = sections["Release notes"]
    changelog_checked = [
        re.search(r"- \[[xX]\] Changelog updated", release_notes) is not None,
        re.search(r"- \[[xX]\] Changelog not needed", release_notes) is not None,
    ]
    release_note_checked = [
        re.search(r"- \[[xX]\] Release note needed and covered by this PR", release_notes)
        is not None,
        re.search(r"- \[[xX]\] Release note not needed", release_notes) is not None,
    ]

    if sum(changelog_checked) != 1:
        errors.append(
            "`## Release notes` must check exactly one changelog intent: updated or not needed."
        )
    if sum(release_note_checked) != 1:
        errors.append(
            "`## Release notes` must check exactly one release-note intent: needed or not needed."
        )


def main() -> int:
    args = parse_args()

    title = args.title or ""
    body = ""

    if args.event_json:
        title, body = load_from_event(args.event_json)
    else:
        if args.body_file:
            body = Path(args.body_file).read_text()

    errors: list[str] = []
    validate_title(title, errors)
    validate_body(body, errors)

    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1

    print("PR metadata looks valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
