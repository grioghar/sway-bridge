#!/bin/bash
# Release build of sway-bridge for macOS, signed with Developer ID (hardened runtime, timestamp).
# No entitlements are needed: the bridge only uses a serial port, CoreMIDI and a localhost socket.
set -euo pipefail
cd "$(dirname "$0")/.."
# The signing identity comes from SWAY_SIGN_IDENTITY or from scripts/signing.local.sh (not in git).
[ -f scripts/signing.local.sh ] && . scripts/signing.local.sh
IDENTITY="${SWAY_SIGN_IDENTITY:?set SWAY_SIGN_IDENTITY to a Developer ID Application identity}"
swift build -c release --product sway-bridge
mkdir -p dist
cp .build/release/sway-bridge dist/sway-bridge
codesign --force --options runtime --timestamp --sign "$IDENTITY" dist/sway-bridge
codesign --verify --strict --verbose=2 dist/sway-bridge
echo "built dist/sway-bridge"
