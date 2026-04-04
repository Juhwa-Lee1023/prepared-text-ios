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

Use the whylog-style PR body template:

```text
## Why this change exists

Lore-id: 1a2b3c4d5e
Constraint: Keep the package surface unchanged for library consumers
Rejected: Leave the policy mismatch in place; it would keep failing bot PR validation
Directive: Revisit if PR automation starts generating whylog-compatible bodies
Tested: ./scripts/check-repo-readiness.sh
Not-tested: End-to-end GitHub Actions rerun from a forked PR
Confidence: medium
Scope-risk: low
Reversibility: clean
```

Keep the entries short and concrete:

- `Lore-id` is a stable lowercase hexadecimal identifier
- `Constraint`, `Rejected`, and `Directive` capture the decision context
- `Tested` and `Not-tested` must explain what you verified locally and what still needs review
- `Confidence`, `Scope-risk`, and `Reversibility` must use the whylog enums

## Pull request checklist

Before opening a PR:

- run the relevant local checks
- update docs when behavior or maintainer workflow changes
- update `CHANGELOG.md` when the change is user-visible
- keep PR scope narrow and explain what is intentionally out of scope
- include screenshots or demo links when UI behavior changes
- record concrete `Tested` and `Not-tested` entries in the PR body
- use `Directive` to note follow-up work or linked issues when they matter

## Filing issues

Please use the GitHub issue forms.

- Bugs: include reproduction steps, environment, and expected behavior
- Feature requests: explain the problem first, then the proposal
- Docs/maintenance: keep them concrete and scoped

For usage questions, start with [SUPPORT.md](SUPPORT.md).
For security issues, follow [SECURITY.md](SECURITY.md) and do not open a public bug.
