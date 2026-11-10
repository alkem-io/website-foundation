#!/usr/bin/env bash
# Builds the unofficial English translation PDFs published under static/legal.
# Needs Google Chrome (headless) and pdfunite (poppler).
set -euo pipefail
cd "$(dirname "$0")"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUT=../../static/legal
TMP="$(mktemp -d)"
pdf() { "$CHROME" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="$2" "file://$PWD/$1" >/dev/null 2>&1; }

# Stichting Alkemio: translation written in this folder
pdf stichting_alkemio_statuten_2025_09_en.html "$OUT/stichting_alkemio/stichting_alkemio-statuten_2025_09_en_unofficial_translation.pdf"

# Alkemio Holding: cover page + the supplied translation
pdf alkemio_holding_statuten_en_cover.html "$TMP/cover.pdf"
pdfunite "$TMP/cover.pdf" alkemio_holding_statuten_en_translation_body.pdf "$OUT/alkemio_holding/alkemio_holding_statuten_en_unofficial_translation.pdf"
rm -rf "$TMP"
