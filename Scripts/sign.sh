#!/bin/bash
# Signs the bundle inside-out. codesign --deep does not sign nested bundles
# correctly and is deliberately not used.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-dist/VoltGuard.app}"
IDENTITY="${SIGN_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
    if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        IDENTITY="$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')"
    elif security find-identity -v -p codesigning | grep -q "DevWizardHQ Release"; then
        IDENTITY="DevWizardHQ Release"
    else
        IDENTITY="-"
        echo "▸ No signing identity found; using ad-hoc. Notification permission and login-item approval will reset on every build." >&2
    fi
fi

# Library validation only accepts a bundled framework signed by the same Team
# ID. A self-signed identity has none, so it needs the relaxed entitlements.
if [[ "$IDENTITY" == Developer\ ID* ]]; then
    ENTITLEMENTS="Resources/VoltGuard.entitlements"
else
    ENTITLEMENTS="Resources/VoltGuard-selfsigned.entitlements"
fi

echo "▸ Signing with: $IDENTITY"
echo "▸ Entitlements: $ENTITLEMENTS"

if [[ "$IDENTITY" == "-" ]]; then
    SIGN=(codesign --force --sign -)
else
    SIGN=(codesign --force --timestamp --options runtime --sign "$IDENTITY")
fi

FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$FRAMEWORK" ]]; then
    # Sparkle's own documented order: helpers first, then the framework.
    for nested in \
        "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" \
        "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc" \
        "$FRAMEWORK/Versions/B/Autoupdate" \
        "$FRAMEWORK/Versions/B/Updater.app"
    do
        [[ -e "$nested" ]] || continue
        echo "  ↳ $(basename "$nested")"
        "${SIGN[@]}" "$nested"
    done
    "${SIGN[@]}" "$FRAMEWORK/Versions/B"
    "${SIGN[@]}" "$FRAMEWORK"
fi

"${SIGN[@]}" --entitlements "$ENTITLEMENTS" --identifier com.devwizardhq.voltguard "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

# Library validation failures only surface at load time, so prove the app's
# own framework is actually loadable under this signature.
echo "▸ Verifying the signed app launches"
"$APP/Contents/MacOS/VoltGuard" >/dev/null 2>"$APP.launch.err" &
LAUNCH_PID=$!
sleep 8
if kill -0 "$LAUNCH_PID" 2>/dev/null; then
    kill "$LAUNCH_PID" 2>/dev/null || true
    rm -f "$APP.launch.err"
    echo "✓ Signed $APP"
else
    echo "✗ The signed app exited immediately:" >&2
    cat "$APP.launch.err" >&2
    exit 1
fi
