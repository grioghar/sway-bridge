#!/usr/bin/env python3
"""Generate the Sway Map Max for Live device (ableton/SwayMap/Sway Map.amxd).

The device is a MIDI effect: MIDI passes straight through, incoming CCs feed the
mapping engine in swaymap.js (which must sit next to the .amxd), and an embedded
web view shows the bridge's live overlay.

.amxd layout: 'ampf' u32(4) 'mmmm' 'meta' u32(4) u32(0) 'ptch' u32(len) <patcher JSON> '\\n\\0'
"""
import json, os, struct

SLOTS = 16
ROW_H, TOP = 18, 22
WEB_W = 370                      # overlay is 1280x520 -> 370x150, leaving a status row beneath
COL_W = 330
boxes, lines = [], []
_n = 0


def box(maxclass, patching, presentation=None, **attrs):
    global _n
    _n += 1
    b = {"id": f"obj-{_n}", "maxclass": maxclass, "numinlets": 1, "numoutlets": 0, "patching_rect": patching}
    if presentation:
        b["presentation"] = 1
        b["presentation_rect"] = presentation
    b.update(attrs)
    boxes.append({"box": b})
    return b["id"]


def obj(text, patching, numinlets=1, numoutlets=1, outlettype=None, **attrs):
    return box("newobj", patching, None, text=text, numinlets=numinlets, numoutlets=numoutlets,
               outlettype=outlettype or [""] * numoutlets, **attrs)


def wire(src, dst, outlet=0, inlet=0):
    lines.append({"patchline": {"source": [src, outlet], "destination": [dst, inlet]}})


def param(longname, ptype, **extra):
    v = {"parameter_longname": longname, "parameter_shortname": longname, "parameter_type": ptype}
    v.update(extra)
    return {"valueof": v}


# ---- MIDI path ----
midiin = obj("midiin", [30, 20, 45, 22], outlettype=["int"])
midiout = obj("midiout", [30, 420, 50, 22], numoutlets=0)
wire(midiin, midiout)
parse = obj("midiparse", [120, 60, 120, 22], numoutlets=8, outlettype=["", "", "", "int", "int", "", "int", ""])
wire(midiin, parse)
pack = obj("pack 0 0 0", [120, 120, 90, 22], numinlets=3)          # cc number, value, channel
unpack = obj("unpack 0 0", [120, 90, 70, 22], numoutlets=2, outlettype=["int", "int"])
wire(parse, unpack, 2)                                             # control change: number value
wire(unpack, pack, 0, 0)
wire(unpack, pack, 1, 1)
wire(parse, pack, 6, 2)                                            # channel (arrives before the cc list)
tocc = obj("prepend cc", [120, 150, 70, 22])
wire(pack, tocc)
js = obj("js swaymap.js", [120, 260, 90, 22], varname="engine", saved_object_attributes={"filename": "swaymap.js", "parameter_enable": 0})
wire(tocc, js)

# ---- lifecycle + saved state ----
thisdevice = obj("live.thisdevice", [330, 20, 90, 22], numoutlets=3, outlettype=["bang", "int", "int"])
init = box("message", [330, 50, 40, 22], None, text="init", numinlets=2, numoutlets=1, outlettype=[""])
wire(thisdevice, init)
wire(init, js)
state = obj("pattr mapstate", [330, 110, 90, 22], numoutlets=3, outlettype=["", "", ""], varname="mapstate",
            parameter_enable=1, saved_attribute_attributes=param("Sway Map State", 3, parameter_invisible=1),
            saved_object_attributes={"initial": ["empty"], "parameter_enable": 1, "parameter_mappable": 0})
restore = obj("prepend restore", [330, 140, 95, 22])
wire(state, restore)
wire(restore, js)

# ---- embedded live view + configurator shortcut ----
box("jweb", [450, 20, 208, 85], [0, 0, WEB_W, 150], numoutlets=2, outlettype=["", ""], rendermode=0,
    url="http://localhost:7729/overlay/?field=full")
openbtn = box("live.text", [450, 120, 90, 18], [2, 152, 80, 16], numoutlets=2, outlettype=["", ""],
              mode=0, text="Configurator", texton="Configurator", parameter_enable=1, varname="open_config",
              saved_attribute_attributes=param("Open Configurator", 2, parameter_enum=["val1", "val2"], parameter_invisible=2))
launch = box("message", [450, 145, 330, 22], None, text=";\rmax launchbrowser http://localhost:7729/config/",
             numinlets=2, numoutlets=1, outlettype=[""])
box("live.comment", [560, 120, 200, 18], [86, 152, WEB_W - 88, 16], text="loading…", textjustification=0, varname="status")
# A live.text in button mode sends a bang, not 1; accept either.
sel1 = obj("route bang 1", [450, 100, 40, 22], numoutlets=3, outlettype=["", "", ""])
wire(openbtn, sel1)
wire(sel1, launch)
wire(sel1, launch, 1)

# ---- mapping slots ----
def header(col):
    x = WEB_W + 8 + col * COL_W
    for text, dx, w in (("Source", 38, 60), ("Target", 132, 110), ("Min", 252, 30), ("Max", 284, 30)):
        box("live.comment", [700, 20, w, 18], [x + dx, 3, w, 16], text=text, textjustification=0)

header(0)
header(1)
for i in range(SLOTS):
    col, row = divmod(i, 8)
    x = WEB_W + 8 + col * COL_W
    y = TOP + row * ROW_H
    py = 60 + i * 30
    learn = box("live.text", [700, py, 36, 16], [x, y, 36, 16], numoutlets=2, outlettype=["", ""], mode=1,
                text="Learn", texton="…CC", parameter_enable=1, varname=f"learn_{i}",
                saved_attribute_attributes=param(f"Learn {i + 1}", 2, parameter_enum=["val1", "val2"], parameter_invisible=2))
    p = obj(f"prepend learn {i}", [745, py, 95, 22]); wire(learn, p); wire(p, js)
    box("live.comment", [850, py, 60, 18], [x + 38, y, 56, 16], text="—", textjustification=0, varname=f"src_{i}")
    mapb = box("live.text", [915, py, 32, 16], [x + 96, y, 34, 16], numoutlets=2, outlettype=["", ""], mode=0,
               text="Map", texton="Map", parameter_enable=1, varname=f"map_{i}",
               saved_attribute_attributes=param(f"Map {i + 1}", 2, parameter_enum=["val1", "val2"], parameter_invisible=2))
    s = obj("route bang 1", [950, py, 40, 22], numoutlets=3, outlettype=["", "", ""]); wire(mapb, s)
    m = box("message", [995, py, 50, 22], None, text=f"map {i}", numinlets=2, numoutlets=1, outlettype=[""]); wire(s, m); wire(s, m, 1); wire(m, js)
    box("live.comment", [1050, py, 120, 18], [x + 132, y, 118, 16], text="—", textjustification=0, varname=f"dst_{i}")
    for name, dx, initial in (("min", 252, 0), ("max", 284, 100)):
        nb = box("live.numbox", [1175 + (40 if name == "max" else 0), py, 36, 15], [x + dx, y, 30, 15], numoutlets=2,
                 outlettype=["", "float"], parameter_enable=1, varname=f"{name}_{i}",
                 saved_attribute_attributes=param(f"{name.title()} {i + 1}", 0, parameter_mmin=0.0, parameter_mmax=100.0,
                                                  parameter_initial_enable=1, parameter_initial=[initial], parameter_unitstyle=5))
        p = obj(f"prepend {name} {i}", [1260 + (100 if name == "max" else 0), py, 90, 22]); wire(nb, p); wire(p, js)
    clr = box("live.text", [1460, py, 16, 16], [x + 316, y, 12, 16], numoutlets=2, outlettype=["", ""], mode=0,
              text="×", texton="×", parameter_enable=1, varname=f"clear_{i}",
              saved_attribute_attributes=param(f"Clear {i + 1}", 2, parameter_enum=["val1", "val2"], parameter_invisible=2))
    s = obj("route bang 1", [1480, py, 40, 22], numoutlets=3, outlettype=["", "", ""]); wire(clr, s)
    m = box("message", [1525, py, 55, 22], None, text=f"clear {i}", numinlets=2, numoutlets=1, outlettype=[""]); wire(s, m); wire(s, m, 1); wire(m, js)
    obj("live.remote~", [1590, py, 80, 22], numinlets=2, numoutlets=1, outlettype=[""], varname=f"remote_{i}")

patcher = {"patcher": {
    "fileversion": 1,
    "appversion": {"major": 9, "minor": 1, "revision": 5, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [60.0, 100.0, 1700.0, 640.0],
    "openinpresentation": 1,
    "default_fontsize": 10.0, "default_fontface": 0, "default_fontname": "Arial Bold",
    "gridsize": [8.0, 8.0],
    "devicewidth": float(WEB_W + 8 + 2 * COL_W + 4),
    "description": "Map the Audima Sway's controls to any Live parameter", "digest": "", "tags": "", "style": "",
    "subpatcher_template": "", "title": "Sway Map",
    "boxes": boxes, "lines": lines,
    "dependency_cache": [{"name": "swaymap.js", "bootpath": ".", "type": "TEXT", "implicit": 1}],
    "latency": 0, "autosave": 0,
}}

out_dir = os.path.join(os.path.dirname(__file__), "..", "ableton", "SwayMap")
os.makedirs(out_dir, exist_ok=True)
body = json.dumps(patcher, indent="\t").encode() + b"\n\x00"
with open(os.path.join(out_dir, "Sway Map.amxd"), "wb") as f:
    f.write(b"ampf" + struct.pack("<I", 4) + b"mmmm" + b"meta" + struct.pack("<II", 4, 0) + b"ptch" + struct.pack("<I", len(body)) + body)
print(f"wrote Sway Map.amxd: {len(boxes)} objects, {len(lines)} connections")
