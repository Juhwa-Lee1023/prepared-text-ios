# validate-whylog

Runs `whylog validate` using a local project install when present, or falls back to `npx --yes --package whylog@0.4.0 whylog ...` from the checked-out repository root.

This repository intentionally keeps whylog scaffold-only:

- no `package.json` changes
- no committed Node lockfiles
- staged adoption with `--skip-unstructured --strict`
- a pinned `0.4.0` on-demand CLI so CI semantics stay stable across later whylog releases
- repo-root execution so range validation can see the checked-out Git history in this Swift Package repository

Once every new commit is expected to carry whylog trailers, you can remove `--skip-unstructured` from the workflow inputs.
