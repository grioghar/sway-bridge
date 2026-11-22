#!/bin/bash
# Release build of Sway Bridge.app and the sway-bridge tool for macOS, signed with Developer ID (hardened runtime, timestamp).
# No entitlements are needed: the bridge only uses a serial port, CoreMIDI and a localhost socket.
set -euo pipefail
cd "$(dirname "$0")/.."
# The signing identity comes from SWAY_SIGN_IDENTITY or from scripts/signing.local.sh (not in git).
[ -f scripts/signing.local.sh ] && . scripts/signing.local.sh
IDENTITY="${SWAY_SIGN_IDENTITY:?set SWAY_SIGN_IDENTITY to a Developer ID Application identity}"
swift build -c release --product sway-bridge
swift build -c release --product SwayApp
mkdir -p dist

# Command-line bridge (same program as on Windows and Linux).
cp .build/release/sway-bridge dist/sway-bridge
codesign --force --options runtime --timestamp --sign "$IDENTITY" dist/sway-bridge
codesign --verify --strict dist/sway-bridge

# Native app: the configurator plus the bridge, with the overlay pages in its resources.
APP="dist/Sway Bridge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SwayApp "$APP/Contents/MacOS/Sway Bridge"
cp mac/Info.plist "$APP/Contents/Info.plist"
cp mac/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R web "$APP/Contents/Resources/web"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --deep --verbose=2 "$APP"
echo "built dist/sway-bridge and $APP"
