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
    "Changes",
    "Testing",
    "Risks and follow-ups",
    "Related issues",
]
SECTION_PATTERN = re.compile(r"^## (?P<heading>.+?)\s*$", re.MULTILINE)
HTML_COMMENT_PATTERN = re.compile(r"<!--.*?-->", re.DOTALL)
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
    if cleaned in {"", "-", "TBD"}:
        return True

    return False


def is_bot_author(author_login: str) -> bool:
    return author_login in BOT_LOGINS


def strip_html_comments(value: str) -> str:
    return HTML_COMMENT_PATTERN.sub("", value)


def parse_sections(body: str) -> dict[str, str]:
    sections: dict[str, str] = {}
    matches = list(SECTION_PATTERN.finditer(body))

    for index, match in enumerate(matches):
        heading = match.group("heading").strip()
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        sections[heading] = body[start:end].strip()

    return sections


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


def validate_template_body(body: str, errors: list[str]) -> None:
    if not body.strip():
        errors.append("PR body is required.")
        return

    sections = parse_sections(body)

    for section in REQUIRED_SECTIONS:
        if section not in sections:
            errors.append(f"PR body must include `## {section}`.")

    if errors:
        return

    for section in REQUIRED_SECTIONS:
        cleaned = strip_html_comments(sections[section]).strip()
        if looks_empty(cleaned):
            errors.append(f"`## {section}` must not be empty.")


def validate_body(body: str, author_login: str, errors: list[str]) -> None:
    if is_bot_author(author_login):
        return

    validate_template_body(body, errors)


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
