# Sway Bridge

Unofficial tools for the [Audima Labs Sway](https://audima.com.au) MIDI controller:

- **sway-bridge** — a small local app (Swift, no dependencies) that talks to the Sway over its
  serial configuration port, listens to its MIDI output, and serves the pages below on
  `http://localhost:7729`.
- **Sway Bridge.app** (macOS) — a native SwiftUI app with the bridge built in. It shows a
  drawing of the Sway: click a region, pad or dial on it to edit it, and watch pads, dials and
  hand levels light up as you play. It can switch the Sway to any preset (by sending a MIDI
  Program Change) and serves the OBS overlay while it is running.
- **Configurator** (`/config/`) — edit presets, regions, pads and dials in a browser and send
  them to the device.
- **OBS overlay** (`/overlay/`) — a live picture of the pads, dials, LED strip and hand
  positions, for use as an OBS browser source.
- **Sway Map** — a Max for Live device that maps any Sway control to any Live parameter.
- **Sway control surface** — an Ableton Live remote script that makes the dials follow the
  selected device and the mixer.

This project is not affiliated with or endorsed by Audima Labs. The protocol was worked out
from a retail unit on firmware 1.3.0; other firmware versions may differ.

## Status

| Piece | State |
| --- | --- |
| Bridge on macOS | Working against real hardware: read, edit, write and verify presets |
| Sway Bridge.app (macOS) | Reads the Sway, edits presets and switches the active preset; sending an edited preset from the app and its live hand levels not yet tried with the hardware |
| Configurator, overlay | Working; overlay hand display checked with simulated input only |
| Sway Map (Max for Live) | Working in Live 12 with the hardware: Learn, Map to a mixer control, and the mapping survives saving and reopening the set |
| Control surface script | Loads in Live 12 and its first dial page steers the selected device; the mixer pages are not yet checked |
| Bridge on Linux | Builds, tests pass and pages are served on Ubuntu 24.04 (Swift 6.4); serial and MIDI not yet tried with hardware |
| Bridge on Windows | Code written; not yet built |

Known gaps: changing a preset's region layout is not supported; the second hand's
controllers always follow the first hand's; the effect of the "retrigger motion" flag is
untested. Every byte of the preset format is identified (see `Sources/SwayKit/Codec.swift`). The eight black buttons and the
dial clicks are not preset settings: seven buttons send fixed notes on channel 2, the eighth
switches the pad layout, and a dial click selects the dial page.

## Running

```bash
swift build -c release
.build/release/sway-bridge          # run from the repository root so it finds ./web
```

Then open <http://localhost:7729/config/>. Quit Audima's own app first: both need the same
serial port.

On macOS, `scripts/build-mac.sh` builds and signs `dist/Sway Bridge.app` and the command-line
`dist/sway-bridge` (set `SWAY_SIGN_IDENTITY` to your Developer ID Application identity). Run one
or the other, not both: they use the same serial port and the same web port. The app keeps its
backups in `~/Library/Application Support/Sway Bridge/backups`.

Options: `--port 7729`, `--web <dir>`, `--backups <dir>`. The bridge listens on 127.0.0.1 only
and saves a copy of the device's project to `backups/` whenever it changes.

### OBS

Add a Browser source pointing at one of:

| URL | Look |
| --- | --- |
| `http://localhost:7729/overlay/` | Solid hardware with filled region boxes |
| `http://localhost:7729/overlay/?style=outline` | Outlines only, thin hand-level lines |
| `…&field=full` / `…&field=levels` / `…&field=0` | Choose the hand display |
| `…&demo=1` | Synthetic performance, for positioning the source |

### Ableton Live

`scripts/install-ableton.sh` copies the control surface script and the Sway Map device into
the Ableton User Library. Restart Live, choose **Sway** under Settings → Link, Tempo & MIDI →
Control Surface, and drop **Sway Map** on the MIDI track that receives the Sway.

To map a control with Sway Map: click **Learn** on a row and move the control on the Sway, press
**Map**, then click the parameter in Live. With the control surface active, dial page 1 is taken
by the selected device and never reaches Sway Map; learn dials from pages 6-8, or use hands.
A region that sends two controllers at once (a trigger and a height, say) is learned by whichever
arrives first, so hold the hand in place before clicking Learn to get the continuous one.

Dial pages with the control surface active: page 1 controls the selected device, pages 2–5
control volume, pan, send A and send B of tracks 1–8, pages 6–8 are left free.

## Platform notes

- **macOS** — CoreMIDI is multi-client, so the bridge and Live can both listen to the Sway.
- **Windows** — the stock USB MIDI driver is single-client: Live and the bridge cannot both
  open the Sway's MIDI port. Configuration over serial is unaffected.
- **Linux** — MIDI is read from the ALSA raw device, which may also be exclusive.

## How it works

The Sway exposes a USB serial port next to its MIDI port. Frames on it look like

```
'S' 'W' 'A' 'Y' | command | length (u16 LE) | payload | XOR of command, length and payload
```

`Sources/SwayKit/Frame.swift` lists the commands, `Client.swift` implements reading and
writing presets, and `Codec.swift` documents the preset layout. An upload must begin with the
preset-selection command; sending fragments without it hangs the device's serial side until it
is power-cycled.

## Development

```bash
swift test
python3 tools/build_m4l.py     # regenerate the Max for Live device
```

The codec tests compare against captures from a real device in `captures/`: the project as
read from a Sway on firmware 1.3.0 (Audima's factory presets), a project file saved by
Audima's app, and a MIDI log of a few gestures. Those tests are skipped if the files are absent.

## Licence

MIT, see [LICENSE](LICENSE). The files in `captures/` hold Audima's factory presets as read from a device and are included only as test data.
