# whylog Agent Rules

- This repository keeps whylog scaffold-only. Do not add `package.json` or Node lockfiles just to use whylog here.
- Read context before editing: `npx --yes --package whylog whylog context <path>`
- Use `npx --yes --package whylog whylog why <path:line>` when a single line or symbol is the question
- Use `npx --yes --package whylog whylog search <query>` if you do not know which path to inspect yet
- Check rejected paths when revisiting tricky code: `npx --yes --package whylog whylog rejected <path>`
- Use `npx --yes --package whylog whylog commit -i` or `--from-json` for structured commit messages
- Run `npx --yes --package whylog whylog validate --range origin/main..HEAD --skip-unstructured --strict` before finalizing a branch
- Keep secrets, tokens, private endpoints, and personal data out of trailers
