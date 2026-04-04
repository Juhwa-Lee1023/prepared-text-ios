# Maintainers

This document describes the minimum maintainer workflow for `prepared-text-ios`.

## Branch naming

Use short descriptive branch names:

- `feat/...`
- `fix/...`
- `docs/...`
- `refactor/...`
- `chore/...`
- `release/...`

Do not merge directly to `main`.

## Pull request naming

PR titles must follow:

```text
type(scope): summary
```

Examples:

- `fix(core): correct line fragment height accounting`
- `docs(readme): clarify Stage 0 adoption`
- `ci(repo): add release-check workflow`

Validate locally before opening a PR:

```bash
./scripts/check-pr.sh --title "fix(core): summary" --body-file /path/to/body.md
```

## Labels

Repository labels live in:

- `.github/labels.json`

Use them consistently:

- `type:*` for release note grouping
- `area:*` for routing
- `status:*` for triage state
- `priority: release-blocker` for changes that must land before a release

## Merge expectations

- Prefer squash merges for normal feature and fix work.
- Keep the merge message aligned with the validated PR title.
- Do not merge a PR that is missing release intent, tests, or linked issue context.
- Require green CI before merge unless an administrator override is truly necessary.

## Release steps

1. Update `CHANGELOG.md`.
2. Run `./scripts/prepare-release.sh --version X.Y.Z`.
3. Create the annotated tag with `./scripts/create-tag.sh --version X.Y.Z`.
4. Push the tag and draft the GitHub release.
5. Verify generated release notes, local reports in `.build/reports/`, and demo assets before publishing.
