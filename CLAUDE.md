# CLAUDE.md

@AGENTS.md

## Project Context

Canonical pandoc tooling for typeset research docs. A Dockerised pandoc + TeX Live install (base image: `pandoc/latex:3.6`, Alpine), a wrapper script (`render.sh`) with idempotent build + stdin/stdout interface, and an opinionated default style in `defaults/default.yaml`. Sibling research libraries (`loom`, `ondes`, `fws`, `samgria`, `rltrain`, `xptrack`) consume `quill` to render results notes and reports — anything they generate as markdown is piped through `quill` to produce the canonical typeset output. The wrapper is shell-only; there is no Python code, no package, and no API beyond the pandoc CLI.
