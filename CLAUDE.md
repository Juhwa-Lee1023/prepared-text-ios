# whylog Rules

- This repository uses whylog in scaffold-only mode. Do not add `package.json`, `package-lock.json`, or other Node dependency files just to run it.
- Before editing, inspect relevant decision context with `npx --yes --package whylog@0.4.0 whylog context <path>`.
- Use `npx --yes --package whylog@0.4.0 whylog why <path:line>` when a specific line or symbol needs context.
- Use `npx --yes --package whylog@0.4.0 whylog search <query>` when you do not know the path yet.
- Avoid repeating rejected approaches; check `npx --yes --package whylog@0.4.0 whylog rejected <path>` when unsure.
- Create commits with `npx --yes --package whylog@0.4.0 whylog commit -i` or `--from-json`.
- Run `npx --yes --package whylog@0.4.0 whylog validate --range origin/main..HEAD --skip-unstructured --strict` before proposing a commit.
- Never place secrets, tokens, private endpoints, or internal-only operational details in commit trailers.
