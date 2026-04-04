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

WHYLOG_HEADING = "Why this change exists"
LORE_ID_PATTERN = re.compile(r"^[0-9a-f]{8,16}$")
WHYLOG_SINGLE_VALUE_FIELDS = {
    "Lore-id",
    "Confidence",
    "Scope-risk",
    "Reversibility",
}
WHYLOG_REQUIRED_FIELDS = [
    "Lore-id",
    "Constraint",
    "Rejected",
    "Directive",
    "Tested",
    "Not-tested",
    "Confidence",
    "Scope-risk",
    "Reversibility",
]
CONFIDENCE_VALUES = {"low", "medium", "high"}
SCOPE_RISK_VALUES = {"low", "medium", "high"}
REVERSIBILITY_VALUES = {"clean", "partial", "hard"}
BOT_LOGINS = {
    "app/dependabot",
    "dependabot[bot]",
    "dependabot-preview[bot]",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate pull request metadata.")
    parser.add_argument("--title", help="Pull request title")
    parser.add_argument("--body-file", help="Path to a file containing the PR body")
    parser.add_argument("--event-json", help="Path to a pull_request GitHub event payload")
    parser.add_argument("--author", help="Pull request author login")
    return parser.parse_args()


def load_from_event(path: str) -> tuple[str, str, str]:
    payload = json.loads(Path(path).read_text())
    pr = payload.get("pull_request", {})
    author_login = ""
    user = pr.get("user")
    if isinstance(user, dict):
        author_login = user.get("login") or ""
    return (pr.get("title") or "", pr.get("body") or "", author_login)


def looks_empty(value: str) -> bool:
    cleaned = value.strip()
    if cleaned in {"", "-", "TBD", "None.", "Not applicable.", "N/A"}:
        return True

    return False


def is_bot_author(author_login: str) -> bool:
    return author_login in BOT_LOGINS


def parse_whylog_fields(body: str) -> dict[str, list[str]]:
    fields: dict[str, list[str]] = {}

    for line in body.splitlines():
        match = re.match(r"^(?P<key>[A-Za-z][A-Za-z-]*):\s*(?P<value>.*)$", line)
        if not match:
            continue
        key = match.group("key").strip()
        value = match.group("value").strip()
        fields.setdefault(key, []).append(value)

    return fields


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


def validate_whylog_body(body: str, errors: list[str]) -> None:
    if not body.strip():
        errors.append("PR body is required.")
        return

    if f"## {WHYLOG_HEADING}" not in body:
        errors.append(f"PR body must include `## {WHYLOG_HEADING}`.")
        return

    fields = parse_whylog_fields(body)

    for field in WHYLOG_REQUIRED_FIELDS:
        if field not in fields:
            errors.append(f"Missing required whylog field `{field}:`.")

    if errors:
        return

    for field in WHYLOG_REQUIRED_FIELDS:
        non_empty_values = [value for value in fields[field] if not looks_empty(value)]
        if not non_empty_values:
            errors.append(f"`{field}:` must not be empty.")

    if errors:
        return

    for field in WHYLOG_SINGLE_VALUE_FIELDS:
        if len(fields[field]) != 1:
            errors.append(f"`{field}:` must appear exactly once.")

    lore_id = fields["Lore-id"][0]
    if not LORE_ID_PATTERN.match(lore_id):
        errors.append("`Lore-id:` must be lowercase hexadecimal and 8 to 16 characters long.")

    if fields["Confidence"][0] not in CONFIDENCE_VALUES:
        errors.append("`Confidence:` must be one of: low, medium, high.")
    if fields["Scope-risk"][0] not in SCOPE_RISK_VALUES:
        errors.append("`Scope-risk:` must be one of: low, medium, high.")
    if fields["Reversibility"][0] not in REVERSIBILITY_VALUES:
        errors.append("`Reversibility:` must be one of: clean, partial, hard.")


def validate_body(body: str, author_login: str, errors: list[str]) -> None:
    if is_bot_author(author_login):
        return

    validate_whylog_body(body, errors)


def main() -> int:
    args = parse_args()

    title = args.title or ""
    body = ""
    author_login = args.author or ""

    if args.event_json:
        title, body, author_login = load_from_event(args.event_json)
    else:
        if args.body_file:
            body = Path(args.body_file).read_text()

    errors: list[str] = []
    validate_title(title, errors)
    validate_body(body, author_login, errors)

    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1

    print("PR metadata looks valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
