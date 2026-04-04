# Versioning

`prepared-text-ios` uses Semantic Versioning.

Tag format:

- `v0.1.0`
- `v0.1.1`
- `v0.2.0`
- `v1.0.0`

## SemVer rules used here

- Increment **patch** for backward-compatible fixes.
- Increment **minor** for backward-compatible additions or meaningful adoption improvements.
- Increment **major** for breaking public API or behavior changes.

## Pre-1.0 expectations

Before `1.0.0`, the project may still tighten API or behavior more aggressively, but releases should still follow SemVer and document breaking changes clearly.

## Tagging policy

- Tags must be annotated tags, not lightweight tags.
- Tags must be created through `./scripts/create-tag.sh` unless there is a compelling reason not to.
- Every tag must correspond to a changelog section in `CHANGELOG.md`.
