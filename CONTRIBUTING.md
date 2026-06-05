# Contributing

## Coding style

- Bash: `set -euo pipefail` at the top of every script; quote every variable expansion; prefer `[[ ... ]]` over `[ ... ]`.
- Dockerfile: combine related `RUN` steps to keep layer count small, but keep unrelated steps (fonts vs TeX packages) separate so changes invalidate the right layer.
- YAML: two-space indent, no tabs.

## Testing changes

Run the smoke test before pushing anything that touches `Dockerfile`, `defaults/`, `templates/`, or `render.sh`:

```bash
./tests/smoke.sh
```

It builds the image (or reuses it if unchanged), renders `tests/fixtures/smoke.md` to PDF, and asserts the output is a non-empty valid PDF. The same test runs in CI; failing it locally before pushing saves a round trip.

## Commit style

Conventional Commits, no scope (this is a research repo — see `~/.claude/rules/workflows/pull-requests.md`):

```
feat: add bibliography support to default defaults
fix: handle whitespace in CWD when mounting /data
docs: clarify env-var passthrough in README
```

## Releasing

Tag releases as `v<major>.<minor>.<patch>` on `main`. The CI workflow validates the image still builds and the smoke test still passes on every push, so a tag is just a marker — no separate release pipeline.
