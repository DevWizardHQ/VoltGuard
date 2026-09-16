#!/bin/bash
# Builds the styled installer image. Falls back to a plain hdiutil image only
# when create-dmg is unavailable, so a release never silently ships unstyled.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-dist/VoltGuard.app}"
VERSION="${VERSION:-0.0.0}"
DMG="dist/VoltGuard.dmg"
STAGING="dist/dmg-root"
BACKGROUND="Resources/Assets/dmg-background.tiff"
ICON="Resources/Assets/AppIcon.icns"

rm -rf "$STAGING" "$DMG"

if command -v create-dmg >/dev/null 2>&1; then
    create-dmg \
        --volname "VoltGuard $VERSION" \
        ${ICON:+--volicon "$ICON"} \
        --background "$BACKGROUND" \
        --window-pos 200 140 \
        --window-size 660 400 \
        --icon-size 112 \
        --text-size 13 \
        --icon "VoltGuard.app" 165 200 \
        --app-drop-link 495 200 \
        --hide-extension "VoltGuard.app" \
        --no-internet-enable \
        "$DMG" "$APP"
else
    echo "▸ create-dmg not found (brew install create-dmg); building an unstyled image" >&2
    mkdir -p "$STAGING"
    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create -volname "VoltGuard $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
    rm -rf "$STAGING"
fi

shasum -a 256 "$DMG" > "$DMG.sha256"
echo "✓ Built $DMG"
