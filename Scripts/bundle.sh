#!/bin/bash
# Assembles VoltGuard.app from the SwiftPM executable.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
VERSION="${VERSION:-0.0.0}"
BUILD="${BUILD:-1}"
APP="dist/VoltGuard.app"
CONTENTS="$APP/Contents"

echo "▸ swift build -c $CONFIG"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"

if [[ "$CONFIG" == "release" ]]; then
    # Two single-arch builds joined with lipo, rather than `--arch arm64
    # --arch x86_64`: that flag pair routes through a build path that rejects
    # per-target swiftLanguageMode settings.
    ARM_TRIPLE="arm64-apple-macosx14.0"
    X86_TRIPLE="x86_64-apple-macosx14.0"
    swift build -c release --triple "$ARM_TRIPLE"
    swift build -c release --triple "$X86_TRIPLE"
    lipo -create -output "$CONTENTS/MacOS/VoltGuard" \
        "$(swift build -c release --triple "$ARM_TRIPLE" --show-bin-path)/VoltGuard" \
        "$(swift build -c release --triple "$X86_TRIPLE" --show-bin-path)/VoltGuard"
else
    swift build -c "$CONFIG"
    cp "$(swift build -c "$CONFIG" --show-bin-path)/VoltGuard" "$CONTENTS/MacOS/VoltGuard"
fi

echo "▸ Assembling $APP"

sed -e "s/__VERSION__/$VERSION/" \
    -e "s/__BUILD__/$BUILD/" \
    Resources/Info.plist.in > "$CONTENTS/Info.plist"

if [[ -f Resources/Assets/AppIcon.icns ]]; then
    cp Resources/Assets/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"
fi
cp LICENSE "$CONTENTS/Resources/LICENSE" 2>/dev/null || true

# Sparkle ships as a binary xcframework; SwiftPM leaves it in the artifacts
# directory, so the bundle has to embed it explicitly.
SPARKLE_FRAMEWORK="$(find .build/artifacts -type d -name 'Sparkle.framework' -path '*macos-arm64_x86_64*' 2>/dev/null | head -1)"
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
    echo "▸ Embedding Sparkle.framework"
    rsync -a --delete "$SPARKLE_FRAMEWORK" "$CONTENTS/Frameworks/"
else
    echo "▸ Sparkle.framework not found; in-app updates will be unavailable" >&2
fi

install_name_tool -add_rpath "@executable_path/../Frameworks" "$CONTENTS/MacOS/VoltGuard" 2>/dev/null || true

echo "✓ Built $APP ($VERSION build $BUILD)"
