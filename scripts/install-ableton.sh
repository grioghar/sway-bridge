#!/bin/bash
# Copy the Sway control surface script and the Sway Map device into the Ableton User Library.
# Restart Live afterwards, then choose "Sway" under Settings > Link, Tempo & MIDI > Control Surface.
set -euo pipefail
cd "$(dirname "$0")/.."
LIB="${ABLETON_USER_LIBRARY:-$HOME/Music/Ableton/User Library}"
[ -d "$LIB" ] || { echo "Ableton User Library not found at $LIB (set ABLETON_USER_LIBRARY)"; exit 1; }
python3 tools/build_m4l.py
mkdir -p "$LIB/Remote Scripts/Sway" "$LIB/Presets/MIDI Effects/Max MIDI Effect/Sway Map"
cp ableton/Sway/*.py "$LIB/Remote Scripts/Sway/"
cp "ableton/SwayMap/Sway Map.amxd" ableton/SwayMap/swaymap.js "$LIB/Presets/MIDI Effects/Max MIDI Effect/Sway Map/"
echo "installed into $LIB"
