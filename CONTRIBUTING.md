# Contributing

Thanks for contributing to `prepared-text-ios`.

This repository is intentionally narrow. Please keep changes aligned with the documented product scope:

- read-only prepared text
- UIKit-first rendering
- SwiftUI bridge
- repeated width negotiation and height prediction
- no editing, selection, caret, IME, or broad `UILabel` parity work unless the maintainers explicitly approve that direction

## Local setup

1. Install Xcode 16 or later.
2. Make sure the active toolchain can build Swift 6 packages.
3. Clone the repository and open it in Terminal.
4. Run the baseline checks:

```bash
swift build
swift test
swift run PretextValidation --mode gate
swift run PretextBenchmarks
./scripts/run-ios-demo-tests.sh
```

If you are preparing a merge or release candidate, also run:

```bash
./scripts/run-release-checks.sh
./scripts/check-repo-readiness.sh
```

## Whylog setup

This repository keeps whylog scaffold-only on top of a Swift Package layout:

- no `package.json`
- no committed Node lockfiles
- no `npm install` step just to use whylog

Use the on-demand CLI path instead:

```bash
npx --yes --package whylog@0.4.0 whylog doctor
npx --yes --package whylog@0.4.0 whylog commit -i
npx --yes --package whylog@0.4.0 whylog validate --range origin/main..HEAD --skip-unstructured --strict
```

`--skip-unstructured` stays enabled for now so existing history can remain mixed while new work adopts whylog trailers. The on-demand command is pinned to `0.4.0` so this Swift Package repository does not silently change validation behavior when newer whylog releases appear.

## Branch naming

Use short descriptive branch names in kebab case. Recommended prefixes:

- `feat/...`
- `fix/...`
- `docs/...`
- `refactor/...`
- `chore/...`
- `release/...`

Avoid pushing work directly to `main`.

## Pull request titles

PR titles must follow:

```text
type(scope): summary
```

Examples:

- `feat(swiftui): add PreparedCopy examples`
- `fix(core): correct line fragment height accounting`
- `docs(readme): explain Stage 0 adoption`

Allowed `type` values:

- `feat`
- `fix`
- `docs`
- `refactor`
- `perf`
- `test`
- `build`
- `ci`
- `chore`
- `release`

You can validate a title and body locally with:

```bash
./scripts/check-pr.sh --title "fix(core): example" --body-file /path/to/body.md
```

## Pull request body

Use the OSS-style PR body template in `.github/pull_request_template.md`.
whylog is for commit messages and commit validation here, not for PR bodies.

```text
## Summary

Align the contributor workflow with a conventional open-source PR body format.
This keeps whylog focused on commits while making PR history easier to scan.

## Changes

- replace the whylog-style PR template with a sectioned OSS template
- validate required PR sections in the metadata check script
- update contributor and maintainer docs to match the new workflow

## Testing

- `./scripts/check-pr.sh --title "docs(repo): example" --body-file /tmp/pr-body.md`
- `./scripts/check-repo-readiness.sh`

## Risks and follow-ups

- None.

## Related issues

- Refs #123
```

Keep the sections concrete and reviewable:

- `Summary` explains the problem and outcome
- `Changes` lists the main code, docs, or workflow updates
- `Testing` records the commands you ran and the high-signal results
- `Risks and follow-ups` captures rollout concerns, known limitations, or explicit `None.`
- `Related issues` links the issue or follow-up when one exists

## Pull request checklist

Before opening a PR:

- run the relevant local checks
- update docs when behavior or maintainer workflow changes
- update `CHANGELOG.md` when the change is user-visible
- keep PR scope narrow and explain what is intentionally out of scope
- include screenshots or demo links when UI behavior changes
- record concrete testing evidence in the `## Testing` section
- use `## Risks and follow-ups` and `## Related issues` to capture roll-forward work when it matters

## Filing issues

Please use the GitHub issue forms.

- Bugs: include reproduction steps, environment, and expected behavior
- Feature requests: explain the problem first, then the proposal
- Docs/maintenance: keep them concrete and scoped

For usage questions, start with [SUPPORT.md](SUPPORT.md).
For security issues, follow [SECURITY.md](SECURITY.md) and do not open a public bug.
