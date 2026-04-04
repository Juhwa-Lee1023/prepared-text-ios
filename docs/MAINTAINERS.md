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

PR bodies must use the sectioned OSS template in `.github/pull_request_template.md`:

- `## Summary`
- `## Changes`
- `## Testing`
- `## Risks and follow-ups`
- `## Related issues`

whylog remains commit-only in this repository. Do not mirror whylog trailers into PR bodies.

## whylog rollout

This repository keeps whylog scaffold-only:

- keep the SwiftPM layout intact
- do not add `package.json` or Node lockfiles just to run whylog
- use `npx --yes --package whylog@0.4.0 whylog ...` for local commands
- keep `validate-whylog.yml` as an independent workflow until you intentionally fold it into other checks
- keep `--skip-unstructured` enabled until the repository is ready to require structured trailers on every commit
- keep the on-demand CLI pinned so later whylog releases do not silently change repository policy

## Labels

Repository labels live in:

- `.github/labels.json`

Use them consistently:

- `type:*` for release note grouping
- `area:*` for routing
- `status:*` for triage state
- `priority: release-blocker` for changes that must land before a release

## Merge expectations

- Prefer merge commits when the branch history is already small and coherent.
- Avoid squash merges when they would discard useful commit history.
- Keep the merge message aligned with the validated PR title.
- Do not merge a PR that is missing a clear summary, concrete testing coverage, or meaningful follow-up context when needed.
- Require green `ci`, `pr-metadata`, and `validate-whylog` checks before merge unless an administrator override is truly necessary.

## Release steps

1. Update `CHANGELOG.md`.
2. Run `./scripts/prepare-release.sh --version X.Y.Z`.
3. Create the annotated tag with `./scripts/create-tag.sh --version X.Y.Z`.
4. Push the tag and draft the GitHub release.
5. Verify generated release notes, local reports in `.build/reports/`, and demo assets before publishing.
