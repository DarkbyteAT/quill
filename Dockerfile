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
LABEL org.opencontainers.image.version="0.1.0"

# Fonts. EB Garamond (serif), Source Code Pro (mono), Inter (sans).
# fontconfig is already present in the base image; rebuild the cache after.
RUN apk add --no-cache \
      font-eb-garamond \
      font-adobe-source-code-pro \
      font-inter \
 && fc-cache -f

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

# Bake the opinionated defaults and any custom templates into a stable
# location inside the image. render.sh mounts the user's CWD at /data and
# invokes pandoc with --defaults pointing at this path by default.
RUN mkdir -p /opt/quill/defaults /opt/quill/templates
COPY defaults/ /opt/quill/defaults/
COPY templates/ /opt/quill/templates/

WORKDIR /data
ENTRYPOINT ["pandoc"]
