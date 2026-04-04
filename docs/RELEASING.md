# Releasing

This repository uses annotated SemVer tags and GitHub Releases.

## Before you start

- make sure `main` is up to date
- confirm the release scope is documented in `CHANGELOG.md`
- verify that repository metadata and community files are current

## Prepare a release

Run the local release preparation helper:

```bash
./scripts/prepare-release.sh --version 0.1.0
```

This checks:

- clean working tree
- repository readiness
- changelog entry presence
- build, tests, validation, benchmarks, and demo simulator checks
- local validation and benchmark reports can be generated successfully

## Create a tag

Create an annotated tag:

```bash
./scripts/create-tag.sh --version 0.1.0
```

Dry run:

```bash
./scripts/create-tag.sh --version 0.1.0 --dry-run
```

Create and push:

```bash
./scripts/create-tag.sh --version 0.1.0 --push
```

## GitHub release notes

GitHub release notes are categorized through:

- `.github/release.yml`

After pushing a tag:

1. Open the release draft in GitHub.
2. Use generated release notes.
3. Edit the summary for clarity.
4. Verify links, screenshots, and changelog wording.

## Asset verification

Before publishing:

- confirm local reports in `.build/reports/` look correct if you generated them during the release pass
- confirm `Apps/PreparedTextDemo/README.md` still matches the shipped demo project path
- confirm screenshots and demo references are not broken
