# quill

Canonical pandoc tooling for typeset research docs. A Dockerised pandoc + TeX Live install, an idempotent wrapper that pipes stdin → stdout, and an opinionated default style so every doc rendered with `quill` looks the same.

quill is infrastructure — every research-doc render in any sibling repo eventually consumes it. The point is that you (or a CI job, or a `pandoc` step inside another tool) can `cat foo.md | quill --to=pdf > foo.pdf` from a clean machine without ever installing TeX Live locally.

## Install

### Recommended: Homebrew

```bash
brew tap DarkbyteAT/quill https://github.com/DarkbyteAT/quill
brew install darkbyteat/quill/quill
```

This installs `quill` to your `PATH` and bundles the Dockerfile, defaults, and templates under `$(brew --prefix)/opt/quill/libexec`. Docker is declared as a dependency, so brew will surface it if missing.

```bash
quill --version                # forwards to `pandoc --version` inside the container
cat paper.md | quill --to=pdf > paper.pdf
```

The first render builds the docker image (a few minutes). Subsequent invocations reuse it — see [Design rationale](#design-rationale) for how the idempotent build works.

The two-argument `brew tap` form is required because Homebrew 5.x no longer accepts local-file formula installs, and quill ships its formula in the main repo rather than a separate `homebrew-quill` tap.

### Alternative: direct script invocation

If you'd rather skip brew, `render.sh` works standalone from a clone:

```bash
git clone https://github.com/DarkbyteAT/quill
cat paper.md | ./quill/render.sh --to=pdf > paper.pdf
```

To get `quill` on `PATH` without brew, symlink `render.sh` — the script resolves its own location through symlinks, so it still finds the bundled Dockerfile, defaults, and templates:

```bash
ln -s "$(pwd)/render.sh" ~/.local/bin/quill
```

## Usage

quill forwards every non-`-e` argument to pandoc unchanged, so anything you can pass to pandoc you can pass to quill.

### Markdown to PDF

```bash
cat paper.md | quill --to=pdf > paper.pdf
quill --to=pdf -o paper.pdf < paper.md
```

### Markdown to HTML

```bash
quill --to=html -o paper.html --standalone < paper.md
```

### With a bibliography

```bash
quill --to=pdf --citeproc --bibliography=refs.bib -o paper.pdf < paper.md
```

`refs.bib` is resolved against the host CWD, which is mounted at `/data` inside the container.

### Overriding the default style

quill applies `defaults/default.yaml` automatically. To replace it, pass your own `--defaults`:

```bash
quill --defaults=./my-defaults.yaml --to=pdf < paper.md > paper.pdf
```

You can also override individual variables on the command line without writing a defaults file:

```bash
quill --to=pdf -V mainfont="Latin Modern Roman" -V fontsize=12pt < paper.md > paper.pdf
```

### Passing environment variables

```bash
quill -e MY_VAR=value --to=pdf < paper.md > paper.pdf
```

`-e` is consumed by the wrapper, forwarded to `docker run --env`, and is **not** passed to pandoc.

## The defaults

`defaults/default.yaml` is quill's opinionated style. The salient choices:

| Choice | Value | Why |
|---|---|---|
| PDF engine | xelatex | Modern OpenType font support; needed for the font choices below |
| Serif | EB Garamond | High-contrast Renaissance design, excellent for long-form reading |
| Sans | Inter | Clean, screen-optimised; pairs well with Garamond |
| Mono | Source Code Pro | Designed for prose-embedded code; consistent stroke weight |
| Size | 11pt, 1in margins, 1.15 line height | Comfortable reading; close to typeset journal norms |
| Links | Coloured (RoyalBlue / ForestGreen for citations) | Visible without boxed-link aesthetic |
| Sections | Numbered, TOC depth 3 | Research-doc default; toggle with `-V number-sections=false` |
| Code | tango syntax theme | High contrast, prints to B/W cleanly |
| Layout | parskip-based (no first-line indent) | Reads better on screen and in PDF than indented paragraphs |

Override any of these via `--defaults` or `-V` (see above).

## Design rationale

### Why Docker

A TeX Live install is hundreds of megabytes, a moving target, and has irritating cross-platform packaging differences. Pinning everything inside an image means the rendered output is reproducible on any machine with Docker — CI, a fresh laptop, a teammate's box. The base image (`pandoc/latex`) already bundles TeX Live, so quill's image just layers fonts, a few extra TeX packages, and the defaults on top.

### Why the idempotent build

Naive wrappers either build the image on every invocation (slow) or build it once and never update (stale). quill computes a SHA-256 over the Dockerfile, defaults, and templates and uses the first 12 hex chars as the image tag. If the inputs haven't changed, the existing image is reused — zero `docker build` overhead. If they have changed, the next invocation rebuilds automatically. No manual cache busting.

The hash is over inputs that actually affect the rendered output. Editing `README.md` doesn't trigger a rebuild; editing `defaults/default.yaml` does.

### Why these fonts

EB Garamond is a digital revival of Claude Garamont's 16th-century types — high contrast, narrow proportions, designed for long-form reading. Source Code Pro was designed by Paul Hunt at Adobe specifically for embedded code in prose contexts (rather than for terminals), so it matches Garamond's weight without standing out. Inter (by Rasmus Andersson) is a clean neo-grotesque that pairs sanely with both — used for figure labels and headings if you opt for sans variants.

All three are open-source, available in the Alpine package repos, and render identically on every install of the image.

### Why stdin/stdout

quill is a Unix filter. It composes:

```bash
git show HEAD:paper.md | quill --to=pdf | open -f -a Preview
```

The wrapper doesn't impose a project structure, a config file location, or a CLI of its own — it's a transparent layer over pandoc. If you can pipe markdown into pandoc, you can pipe it into quill.

## CI / smoke test

`tests/smoke.sh` renders a fixture markdown to PDF and asserts the output is a non-empty valid PDF. Run it locally before committing changes to the Dockerfile, defaults, or render.sh:

```bash
./tests/smoke.sh
```

The same smoke test runs in CI on every push (see `.github/workflows/ci.yml`).

## License

MIT. See `LICENSE`.
