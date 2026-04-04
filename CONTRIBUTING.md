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

## Pull request checklist

Before opening a PR:

- run the relevant local checks
- update docs when behavior or maintainer workflow changes
- update `CHANGELOG.md` when the change is user-visible
- keep PR scope narrow and explain what is intentionally out of scope
- include screenshots or demo links when UI behavior changes
- link an issue, or explicitly say `No issue`

## Filing issues

Please use the GitHub issue forms.

- Bugs: include reproduction steps, environment, and expected behavior
- Feature requests: explain the problem first, then the proposal
- Docs/maintenance: keep them concrete and scoped

For usage questions, start with [SUPPORT.md](SUPPORT.md).
For security issues, follow [SECURITY.md](SECURITY.md) and do not open a public bug.
