#!/usr/bin/env bash
# Exporte la documentation technique en HTML ou PDF (Pandoc requis).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/P7-FSJA/documentation-technique.md"
OUT="${1:-${ROOT}/P7-FSJA/documentation-technique.html}"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "Installer pandoc : sudo apt install pandoc" >&2
  exit 1
fi

if [[ "${OUT}" == *.pdf ]]; then
  if ! command -v pdflatex >/dev/null 2>&1; then
    echo "pdflatex absent — export HTML à la place :" >&2
    OUT="${OUT%.pdf}.html"
    pandoc "${SRC}" -o "${OUT}" --toc --standalone --metadata title="Documentation technique MicroCRM"
    echo "Généré : ${OUT}"
    exit 0
  fi
  pandoc "${SRC}" -o "${OUT}" --toc --metadata title="Documentation technique MicroCRM"
else
  pandoc "${SRC}" -o "${OUT}" --toc --standalone --metadata title="Documentation technique MicroCRM"
fi

echo "Généré : ${OUT}"
