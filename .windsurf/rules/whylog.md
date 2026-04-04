# whylog Rule

- This repository uses whylog as scaffold-only metadata. Do not add package manifests or lockfiles just to run it.
- Read decision context before editing with `npx --yes --package whylog@0.4.0 whylog context <path>`.
- Use `npx --yes --package whylog@0.4.0 whylog why <path:line>` for a specific location and `npx --yes --package whylog@0.4.0 whylog search <query>` when the path is unknown.
- Re-check rejected options before proposing a new approach.
- Use `npx --yes --package whylog@0.4.0 whylog commit -i` or `--from-json` to record structured why/context trailers.
- Run `npx --yes --package whylog@0.4.0 whylog validate --range origin/main..HEAD --skip-unstructured --strict` before final commit.
- Never include secrets, internal URLs, or personal data in commit trailers.
