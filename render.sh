#!/usr/bin/env bash
# quill — canonical pandoc tooling for typeset research docs.
#
# Idempotently builds a docker image bundling pandoc, TeX Live, fonts, and
# opinionated defaults, then pipes stdin through pandoc inside the container.
#
#   cat paper.md | quill --to=pdf > paper.pdf
#   quill --to=html -o paper.html < paper.md
#   quill -e BIBLIOGRAPHY=refs.bib --to=pdf < paper.md > paper.pdf
#
# All non-`-e VAR=val` arguments are forwarded to pandoc unchanged. Add your
# own `--defaults` to override quill's defaults; otherwise quill applies
# `/opt/quill/defaults/default.yaml`.

set -euo pipefail

# Resolve the script's own directory so render.sh works from anywhere and
# still finds the Dockerfile / defaults / templates that determine the image
# tag.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Image-tag hash: any change to the Dockerfile, defaults, or templates yields
# a new tag, so the next invocation rebuilds. Unchanged inputs reuse the
# existing image — zero docker-build cost on the hot path.
hash_inputs() {
  {
    cat "${SCRIPT_DIR}/Dockerfile"
    find "${SCRIPT_DIR}/defaults" "${SCRIPT_DIR}/templates" \
         -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.tex' \
                    -o -name '*.latex' -o -name '*.html' \) \
         -print0 2>/dev/null \
      | sort -z \
      | xargs -0 cat 2>/dev/null || true
  } | shasum -a 256 | cut -c1-12
}

IMAGE_NAME="${QUILL_IMAGE_NAME:-quill}"
IMAGE_TAG="$(hash_inputs)"
IMAGE_REF="${IMAGE_NAME}:${IMAGE_TAG}"

# Idempotent build: skip if the image with this tag already exists locally.
# `docker image inspect` exits non-zero when the image is missing. Build
# output goes to stderr so stdout stays a clean pandoc-output stream;
# `--progress=plain` surfaces failures verbatim instead of hiding them
# behind a TUI progress display that disappears when piped.
if ! docker image inspect "${IMAGE_REF}" >/dev/null 2>&1; then
  echo "quill: building ${IMAGE_REF}" >&2
  docker build \
    --progress=plain \
    --tag "${IMAGE_REF}" \
    --tag "${IMAGE_NAME}:latest" \
    "${SCRIPT_DIR}" >&2
fi

# Split out `-e VAR=val` env-passthrough flags from pandoc args. Everything
# else is forwarded to pandoc verbatim. We also detect whether the user
# supplied their own `--defaults` so we don't double-apply ours.
docker_env_args=()
pandoc_args=()
user_supplied_defaults=0

while (( "$#" )); do
  case "$1" in
    -e)
      if [[ $# -lt 2 ]]; then
        echo "quill: -e requires VAR=val" >&2
        exit 2
      fi
      docker_env_args+=(--env "$2")
      shift 2
      ;;
    -e*)
      docker_env_args+=(--env "${1#-e}")
      shift
      ;;
    --defaults|--defaults=*)
      user_supplied_defaults=1
      pandoc_args+=("$1")
      shift
      ;;
    *)
      pandoc_args+=("$1")
      shift
      ;;
  esac
done

if [[ "${user_supplied_defaults}" -eq 0 ]]; then
  pandoc_args=(--defaults=/opt/quill/defaults/default.yaml "${pandoc_args[@]}")
fi

# Mount CWD at /data so input files (bibliographies, images) and output paths
# resolve naturally. Use `-i` (no `-t`) so stdin streams cleanly when piping.
#
# `${arr[@]+"${arr[@]}"}` is the bash-safe empty-array expansion under
# `set -u`: with no `-e` flags supplied, `docker_env_args` is empty and a
# bare `"${docker_env_args[@]}"` would trip "unbound variable".
exec docker run \
  --rm \
  --interactive \
  --volume "$(pwd):/data" \
  --workdir /data \
  ${docker_env_args[@]+"${docker_env_args[@]}"} \
  "${IMAGE_REF}" \
  ${pandoc_args[@]+"${pandoc_args[@]}"}
