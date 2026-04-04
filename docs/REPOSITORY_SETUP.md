# Repository setup

This repository is prepared as a public-OSS-shaped repository, but the first remote push should be private:

- `Juhwa-Lee1023/prepared-text-ios`

By default:

- the repository name is `prepared-text-ios`
- the default branch is `main`
- the bootstrap helper prefers `GITHUB_REPO_OWNER` and otherwise falls back to the authenticated GitHub CLI user

## Private-first creation flow

Authenticate first:

```bash
gh auth login
```

Create and push the initial private repository:

```bash
gh repo create Juhwa-Lee1023/prepared-text-ios \
  --private \
  --source=. \
  --remote=origin \
  --push \
  --description "Prepared-text layout library for Apple platforms with UIKit and SwiftUI integrations." \
  --disable-wiki \
  --enable-issues
```

Then sync labels and repository settings:

```bash
./scripts/bootstrap-github.sh --owner Juhwa-Lee1023
```

To scaffold whylog without introducing Node package manifests:

```bash
npx --yes --package whylog whylog init --no-package --profile ai
npx --yes --package whylog whylog doctor
```

This repository intentionally keeps whylog as scaffold-only:

- commit `.whylog/`, AI instruction files, and `.github/workflows/validate-whylog.yml`
- do not add `package.json` or lockfiles for whylog
- keep the generated `validate-whylog` workflow independent at first
- use `npx --yes --package whylog whylog validate --range origin/main..HEAD --skip-unstructured --strict` during staged adoption

The bootstrap script can:

- create the repository if it does not exist
- set description and topics
- enable issues
- optionally enable Discussions
- sync labels from `.github/labels.json`
- apply branch protection
- require pull request review
- optionally require CODEOWNERS review

## Repository settings to confirm on the private remote

After bootstrap, verify:

- default branch is `main`
- Issues are enabled
- repository visibility is still `private`
- Discussions are enabled only if you want support routed there
- branch protection is active on `main`
- required checks match the current workflows, including `validate-whylog / validate-whylog`

## Maintainer review before any public switch

Run these before deciding whether to make the repository public:

```bash
./scripts/check-repo-readiness.sh
./scripts/run-release-checks.sh
```

Do not change visibility, create releases, or push tags until the maintainer has manually reviewed the private repository contents.
