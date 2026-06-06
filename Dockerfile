# Canonical pandoc tooling for typeset research docs.
#
# Base: pandoc/latex ships pandoc + a TeX Live 2026 installation with xelatex,
# lualatex, biber, and `tlmgr` for incremental package installs. The base is
# Alpine, so font installs go through `apk` and TeX-side extras through `tlmgr`.
#
# `pandoc/latex` is published amd64-only — no arm64 manifest exists for any
# tag. Pinning `--platform=linux/amd64` makes the image build identically on
# Linux amd64 (native), Apple Silicon (Rosetta / QEMU emulation), and CI.
FROM --platform=linux/amd64 pandoc/latex:3.6

LABEL org.opencontainers.image.title="quill"
LABEL org.opencontainers.image.description="Canonical pandoc tooling for typeset research docs"
LABEL org.opencontainers.image.source="https://github.com/DarkbyteAT/quill"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="0.3.0"

# Fonts are intentionally NOT customised. xelatex's default — Latin Modern,
# the modern enhanced Computer Modern with full Unicode coverage — is the
# iconic typeset-academic look. Users who want different fonts install them
# in their own downstream image (or on the host) and override via their own
# `--defaults` YAML.

# Graphviz + dot2tex for diagrams. Fenced ```dot blocks in markdown become
# native TikZ figures in the rendered PDF — see filters/dot2tikz.lua. The
# Alpine `graphviz` package pulls in libgd / libavif / aom-libs (~40 MB of
# transitive image deps); dot2tex is a small Python tool not in the apk
# repos, so we layer python3 + py3-pip and install it from PyPI.
# `--break-system-packages` is needed because Alpine's py3 install marks
# the system site-packages dir as externally-managed (PEP 668); we own the
# image, there is no other manager.
RUN apk add --no-cache graphviz python3 py3-pip \
 && pip install --break-system-packages --no-cache-dir dot2tex==2.12.0

# TeX packages beyond the base pandoc/latex install. The base already covers
# xelatex/lualatex/biber + a handful of common packages (microtype, booktabs,
# caption, etc.); we add commonly-needed extras for typeset research docs:
# units (siunitx), drawing (pgf), code listings (fvextra), line numbering,
# the bib stack, and structural tweaks.
#
# The base image pins tlmgr to `ftp://tug.org/historic/.../2024/tlnet-final`,
# which is unreachable from inside Docker (FTP through emulated networking is
# unreliable, and many mirrors no longer ship FTP at all). Switch to the
# HTTPS-served Utah mirror of the same frozen 2024 snapshot — content is
# identical, transport is reliable.
RUN tlmgr option repository \
      https://ftp.math.utah.edu/pub/tex/historic/systems/texlive/2024/tlnet-final \
 && tlmgr install \
      siunitx \
      pgf \
      fvextra \
      lineno \
      xstring \
      enumitem \
      titlesec \
      footmisc \
      catchfile \
      newfloat \
      pgfopts

# Bake the opinionated defaults, templates, and pandoc filters into a stable
# location inside the image. render.sh mounts the user's CWD at /data and
# invokes pandoc with --defaults pointing at this path by default; the
# defaults file in turn references filters at /opt/quill/filters/.
RUN mkdir -p /opt/quill/defaults /opt/quill/templates /opt/quill/filters
COPY defaults/ /opt/quill/defaults/
COPY templates/ /opt/quill/templates/
COPY filters/ /opt/quill/filters/

WORKDIR /data
ENTRYPOINT ["pandoc"]
