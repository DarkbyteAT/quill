#!/usr/bin/env bash
# Smoke test: render the fixture markdown to PDF via stdin/stdout and assert
# the output is a non-empty file whose header is `%PDF-`. Run before
# committing changes to Dockerfile / defaults / templates / render.sh.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
FIXTURE="${REPO_ROOT}/tests/fixtures/smoke.md"
OUTPUT="$(mktemp -t quill-smoke.XXXXXX).pdf"
trap 'rm -f "${OUTPUT}"' EXIT

echo "quill smoke: rendering ${FIXTURE} via stdin -> stdout"

"${REPO_ROOT}/render.sh" --to=pdf < "${FIXTURE}" > "${OUTPUT}"

if [[ ! -s "${OUTPUT}" ]]; then
  echo "quill smoke: FAIL — output is empty" >&2
  exit 1
fi

HEADER="$(head -c 5 "${OUTPUT}")"
if [[ "${HEADER}" != "%PDF-" ]]; then
  echo "quill smoke: FAIL — output is not a PDF (got header: ${HEADER})" >&2
  exit 1
fi

SIZE="$(wc -c < "${OUTPUT}" | tr -d ' ')"
echo "quill smoke: PASS — produced a ${SIZE}-byte PDF"
