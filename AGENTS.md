# AGENTS.md

## Commands

```bash
./render.sh --version          # forwards to pandoc inside the container
./tests/smoke.sh               # build image + render fixture + assert non-empty PDF
```

## Critical Rules

- Bash 4+, `set -euo pipefail` everywhere.
- Docker required; no local TeX install assumed.
- Image tag is derived from a hash of `Dockerfile + defaults/* + templates/*`; don't pin tags by hand.
- Defaults live in `defaults/default.yaml` and are baked into `/opt/quill/defaults/default.yaml` inside the image. Users override with their own `--defaults`.
- No filetree diagrams in markdown.
- Conventional Commits, no scope.
