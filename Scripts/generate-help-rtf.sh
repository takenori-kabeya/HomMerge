#!/bin/bash
set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OUT_DIR="${OUTPUT_DIR:-${DERIVED_FILE_DIR:-}}"

if [[ -z "${OUT_DIR}" || "${OUT_DIR}" == "/" ]]; then
    OUT_DIR="${ROOT}/HomMerge/Resources"
fi

find_pandoc() {
    if command -v pandoc >/dev/null 2>&1; then
        command -v pandoc
        return 0
    fi

    for candidate in /opt/homebrew/bin/pandoc /usr/local/bin/pandoc; do
        if [[ -x "${candidate}" ]]; then
            echo "${candidate}"
            return 0
        fi
    done

    return 1
}

if ! PANDOC="$(find_pandoc)"; then
    echo "error: pandoc not found. Install with: brew install pandoc" >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"

generate_one() {
    local input="$1"
    local output="$2"

    if [[ ! -f "${input}" ]]; then
        echo "error: Help source not found at ${input}" >&2
        exit 1
    fi

    "${PANDOC}" "${input}" -f markdown -t rtf -s -o "${output}"

    if [[ ! -f "${output}" ]]; then
        echo "error: failed to generate ${output}" >&2
        exit 1
    fi
}

generate_one "${ROOT}/docs/Help.md" "${OUT_DIR}/Help.rtf"
generate_one "${ROOT}/docs/Help.ja.md" "${OUT_DIR}/Help.ja.rtf"
