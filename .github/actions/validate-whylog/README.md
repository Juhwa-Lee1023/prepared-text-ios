# validate-whylog

Runs `whylog validate` using a local project install when present, or falls back to `npx --yes --package whylog whylog ...`.

This repository intentionally keeps whylog scaffold-only:

- no `package.json` changes
- no committed Node lockfiles
- staged adoption with `--skip-unstructured --strict`

Once every new commit is expected to carry whylog trailers, you can remove `--skip-unstructured` from the workflow inputs.
