#!/bin/bash
# Produces the EdDSA-signed Sparkle appcast from the release archives.
set -euo pipefail
cd "$(dirname "$0")/.."

UPDATES_DIR="${UPDATES_DIR:-dist/updates}"
OUTPUT="${OUTPUT:-dist/appcast.xml}"
DOWNLOAD_PREFIX="${DOWNLOAD_PREFIX:-https://github.com/DevWizardHQ/VoltGuard/releases/latest/download/}"

GENERATE_APPCAST="$(find .build/artifacts -name generate_appcast -type f 2>/dev/null | head -1)"
if [[ -z "$GENERATE_APPCAST" ]]; then
    echo "generate_appcast not found. It ships in the Sparkle SPM artifact; run 'swift build' first." >&2
    exit 1
fi

mkdir -p "$UPDATES_DIR"
[[ -f dist/VoltGuard.zip ]] && cp dist/VoltGuard.zip "$UPDATES_DIR/"

ARGS=("$UPDATES_DIR" --download-url-prefix "$DOWNLOAD_PREFIX" -o "$OUTPUT")
if [[ -n "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
    ARGS+=(--ed-key-file -)
    printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | "$GENERATE_APPCAST" "${ARGS[@]}"
else
    echo "▸ SPARKLE_ED_PRIVATE_KEY not set; the appcast will be unsigned and clients will reject it" >&2
    "$GENERATE_APPCAST" "${ARGS[@]}"
fi

echo "✓ Wrote $OUTPUT"
