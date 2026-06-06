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

# Resolve the script's own directory through any symlinks (e.g. a Homebrew
# bin shim, a user `ln -s` onto PATH) so render.sh finds the Dockerfile /
# defaults / templates that live next to the real file. macOS ships a
# `readlink` without `-f`; walk the symlink chain by hand so we don't depend
# on coreutils.
resolve_script_path() {
  local src="${BASH_SOURCE[0]}"
  while [[ -L "${src}" ]]; do
    local dir
    dir="$(cd -P -- "$(dirname -- "${src}")" &>/dev/null && pwd)"
    src="$(readlink -- "${src}")"
    [[ "${src}" != /* ]] && src="${dir}/${src}"
  done
  cd -P -- "$(dirname -- "${src}")" &>/dev/null && pwd
}
SCRIPT_DIR="$(resolve_script_path)"

# Image-tag hash: any change to the Dockerfile, defaults, or templates yields
# a new tag, so the next invocation rebuilds. Unchanged inputs reuse the
# existing image — zero docker-build cost on the hot path.
hash_inputs() {
  {
    cat "${SCRIPT_DIR}/Dockerfile"
    find "${SCRIPT_DIR}/defaults" "${SCRIPT_DIR}/templates" "${SCRIPT_DIR}/filters" \
         -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.tex' \
                    -o -name '*.latex' -o -name '*.html' -o -name '*.lua' \) \
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
# supplied their own `--defaults` so we don't double-apply ours, and rewrite
# any absolute `-o`/`--output` path so the file lands on the host instead of
# being written to a path that only exists inside the container.
docker_env_args=()
docker_output_mount_args=()
pandoc_args=()
user_supplied_defaults=0
output_target=""

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
    -o)
      if [[ $# -lt 2 ]]; then
        echo "quill: -o requires a path" >&2
        exit 2
      fi
      output_target="$2"
      shift 2
      ;;
    -o*)
      output_target="${1#-o}"
      shift
      ;;
    --output)
      if [[ $# -lt 2 ]]; then
        echo "quill: --output requires a path" >&2
        exit 2
      fi
      output_target="$2"
      shift 2
      ;;
    --output=*)
      output_target="${1#--output=}"
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

# Disable the GHC runtime timer ticker. Without a host TTY (i.e. when quill is
# invoked from a pipe or redirected input — the canonical Unix-filter use),
# the runtime's poll() on the timer hits EINTR every iteration and pandoc
# spams `Ticker: poll failed: Interrupted system call` on stderr ~4-5 times
# per render. `+RTS -V0 -RTS` turns the RTS timer off entirely; pandoc waits
# on its xelatex child process via the standard kernel mechanism and doesn't
# need GHC's tick timer for that, so disabling it is functionally a no-op
# except for the silenced noise. The flag block is consumed by the GHC RTS
# before pandoc's arg parser sees argv, so it doesn't interfere with pandoc.
pandoc_args=("+RTS" "-V0" "-RTS" "${pandoc_args[@]}")

# Resolve the output path against host CWD if one was given, mount its parent
# directory into the container at /quill-out, and forward `-o` to pandoc
# pointing at the in-container basename. Relative paths resolve against host
# CWD because the user types them from the host shell. Tilde expansion is
# the shell's job and has already happened by the time we see the arg.
#
# This step exists because pandoc inside the container has no awareness of
# the host filesystem outside the volume mounts — naively forwarding `-o
# /tmp/foo.pdf` writes to /tmp inside the container, which dies with the
# container.
if [[ -n "${output_target}" ]]; then
  if [[ "${output_target}" = /* ]]; then
    output_abs="${output_target}"
  else
    output_abs="$(pwd)/${output_target}"
  fi
  output_dir="$(dirname -- "${output_abs}")"
  output_base="$(basename -- "${output_abs}")"
  mkdir -p -- "${output_dir}"
  output_dir_real="$(cd -P -- "${output_dir}" && pwd)"
  docker_output_mount_args=(--volume "${output_dir_real}:/quill-out")
  pandoc_args+=(--output="/quill-out/${output_base}")
fi

# Mount CWD at /data so input files (bibliographies, images) and output paths
# resolve naturally. Use `-i` (no `-t`) so stdin streams cleanly when piping.
# `--platform=linux/amd64` pins the runtime platform to match the image
# (`FROM --platform=linux/amd64` in the Dockerfile), silencing docker's
# per-invocation platform-mismatch warning on Apple Silicon.
#
# `${arr[@]+"${arr[@]}"}` is the bash-safe empty-array expansion under
# `set -u`: with no `-e` flags or `-o` supplied, those arrays are empty and a
# bare `"${arr[@]}"` would trip "unbound variable".
exec docker run \
  --rm \
  --interactive \
  --platform=linux/amd64 \
  --volume "$(pwd):/data" \
  --workdir /data \
  ${docker_env_args[@]+"${docker_env_args[@]}"} \
  ${docker_output_mount_args[@]+"${docker_output_mount_args[@]}"} \
  "${IMAGE_REF}" \
  ${pandoc_args[@]+"${pandoc_args[@]}"}
