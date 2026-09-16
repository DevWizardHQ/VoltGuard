#!/bin/bash
# Notarizes and staples. Skips cleanly when notary credentials are absent so a
# release without an Apple Developer account still produces a signed build.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-dist/VoltGuard.dmg}"

if [[ -z "${NOTARY_ISSUER_ID:-}" || -z "${NOTARY_KEY_ID:-}" || -z "${NOTARY_KEY_PATH:-}" ]]; then
    echo "▸ Notary credentials not set; skipping notarization" >&2
    exit 0
fi

echo "▸ Submitting $TARGET to notarytool"
xcrun notarytool submit "$TARGET" \
    --issuer "$NOTARY_ISSUER_ID" \
    --key-id "$NOTARY_KEY_ID" \
    --key "$NOTARY_KEY_PATH" \
    --wait

xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"
echo "✓ Notarized and stapled $TARGET"
