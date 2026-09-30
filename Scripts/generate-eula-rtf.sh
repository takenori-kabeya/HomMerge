#!/bin/bash
set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
INPUT="${ROOT}/docs/EULA.md"
OUTPUT="${OUTPUT:-${DERIVED_FILE_DIR:-}/EULA.rtf}"

if [[ -z "${OUTPUT}" || "${OUTPUT}" == "/EULA.rtf" ]]; then
    OUTPUT="${ROOT}/HomMerge/Resources/EULA.rtf"
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

if [[ ! -f "${INPUT}" ]]; then
    echo "error: EULA source not found at ${INPUT}" >&2
    exit 1
fi

if ! PANDOC="$(find_pandoc)"; then
    echo "error: pandoc not found. Install with: brew install pandoc" >&2
    exit 1
fi

mkdir -p "$(dirname "${OUTPUT}")"
"${PANDOC}" "${INPUT}" -f markdown -t rtf -s -o "${OUTPUT}"

if [[ ! -f "${OUTPUT}" ]]; then
    echo "error: failed to generate ${OUTPUT}" >&2
    exit 1
fi
