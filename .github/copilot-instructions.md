# whylog repository instructions

- This repository uses whylog as scaffold-only commit metadata. Do not introduce `package.json` or Node lockfiles for it.
- Check decision context first with `npx --yes --package whylog whylog context <path>`.
- If you need a line-level explanation, use `npx --yes --package whylog whylog why <path:line>`.
- If the path is unknown, search first with `npx --yes --package whylog whylog search <query>`.
- Preserve `Constraint`, `Rejected`, and `Directive` signals when changing code.
- Use `npx --yes --package whylog whylog commit -i` or `--from-json` to write structured commit trailers.
- Run `npx --yes --package whylog whylog validate --range origin/main..HEAD --skip-unstructured --strict` before finalizing a commit.
- Do not put secrets, tokens, or internal URLs into commit messages.
