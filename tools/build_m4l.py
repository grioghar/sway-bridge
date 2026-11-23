#!/usr/bin/env python3
"""Generate the Sway Map Max for Live device (ableton/SwayMap/Sway Map.amxd).

The device is a MIDI effect: MIDI passes straight through, incoming CCs feed the
mapping engine in swaymap.js (which must sit next to the .amxd), and an embedded
web view shows the bridge's live overlay.

.amxd layout: 'ampf' u32(4) 'mmmm' 'meta' u32(4) u32(0) 'ptch' u32(len) <patcher JSON> '\\n\\0'
"""
import json, os, struct

SLOTS = 16
PER_PAGE = 4                     # mapping rows shown at once; the rest are on further pages
ROW_H, TOP = 34, 26
FS = 14.0                        # text size of the mapping rows
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
# Scale switch off: MIDI passes straight through (gate outlet 1). On: gate outlet 2 takes it apart,
# the notes go through swaymap.js to be moved onto Live's scale, and everything is put back together.
gate = obj("gate 2 1", [30, 60, 60, 22], numinlets=2, numoutlets=2, outlettype=["", ""])
wire(midiin, gate, 0, 1)
wire(gate, midiout, 0)
parse2 = obj("midiparse @hires 2", [30, 200, 120, 22], numoutlets=8, outlettype=["", "", "", "int", "int", "", "int", ""])
wire(gate, parse2, 1)
fmt = obj("midiformat @hires 2", [30, 380, 120, 22], numinlets=7, numoutlets=2, outlettype=["int", ""])
wire(fmt, midiout)
for k in (1, 2, 3, 4, 5, 6):                                       # all but notes go straight across
    wire(parse2, fmt, k, k)
notech = obj("pack 0 0 0", [30, 240, 90, 22], numinlets=3)          # pitch, velocity, channel
noteun = obj("unpack 0 0", [30, 220, 70, 22], numoutlets=2, outlettype=["int", "int"])
wire(parse2, noteun, 0)
wire(noteun, notech, 0, 0)
wire(noteun, notech, 1, 1)
wire(parse2, notech, 6, 2)
tonote = obj("prepend note", [30, 262, 80, 22])
wire(notech, tonote)
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
js = obj("js swaymap.js", [120, 300, 90, 22], numoutlets=2, outlettype=["", ""], varname="engine", saved_object_attributes={"filename": "swaymap.js", "parameter_enable": 0})
wire(tocc, js)
wire(tonote, js)
wire(js, fmt, 1, 6)                                                # channel first (right outlet)...
wire(js, fmt, 0, 0)                                                # ...then pitch and velocity

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
box("live.comment", [560, 120, 200, 18], [86, 150, WEB_W - 88, 18], text="loading…", textjustification=0, varname="status", fontsize=12.0)
# A live.text in button mode sends a bang, not 1; accept either.
sel1 = obj("route bang 1", [450, 100, 40, 22], numoutlets=3, outlettype=["", "", ""])
wire(openbtn, sel1)
wire(sel1, launch)
wire(sel1, launch, 1)

# ---- mapping slots: one wide column, PER_PAGE rows at a time, large text ----
X0 = WEB_W + 10
for text, dx, w in (("Source", 80, 110), ("Target", 262, 60), ("Min", 512, 50), ("Max", 574, 50)):
    box("live.comment", [700, 20, w, 18], [X0 + dx, 3, w, 18], text=text, textjustification=0, fontsize=12.0)
PAGES = (SLOTS + PER_PAGE - 1) // PER_PAGE
tabs = box("live.tab", [700, 0, 200, 18], [X0, 2, 72, 20], numoutlets=3, outlettype=["", "", "float"],
           num_lines_patching=1, num_lines_presentation=1, parameter_enable=1, varname="page", fontsize=11.0,
           saved_attribute_attributes=param("Page", 2, parameter_enum=[str(n + 1) for n in range(PAGES)],
                                            parameter_invisible=2, parameter_unitstyle=0))
pg = obj("prepend page", [910, 0, 90, 22]); wire(tabs, pg); wire(pg, js)
# Switch: move played notes onto the scale set in Live (Live 12's key and scale), and follow it when it changes.
follow = box("live.text", [1010, 0, 150, 18], [X0 + 330, 2, 172, 20], numoutlets=2, outlettype=["", ""], mode=1, fontsize=11.0,
             text="Notes: as played", texton="Notes: follow Live's scale", parameter_enable=1, varname="follow",
             saved_attribute_attributes=param("Follow Scale", 2, parameter_enum=["off", "on"], parameter_invisible=1))
plus1 = obj("+ 1", [1010, 24, 40, 22], numinlets=2, numoutlets=1, outlettype=["int"]); wire(follow, plus1); wire(plus1, gate, 0, 0)
pf = obj("prepend follow", [1060, 24, 95, 22]); wire(follow, pf); wire(pf, js)
for i in range(SLOTS):
    row = i % PER_PAGE
    x, y = X0, TOP + row * ROW_H
    py = 60 + i * 30
    hide = {"hidden": 0 if i < PER_PAGE else 1}
    box("live.comment", [660, py, 30, 18], [x, y + 4, 26, 20], text=str(i + 1), textjustification=1, fontsize=FS, varname=f"num_{i}", **hide)
    learn = box("live.text", [700, py, 36, 16], [x + 28, y, 50, 26], numoutlets=2, outlettype=["", ""], mode=1, fontsize=FS,
                text="Learn", texton="…CC", parameter_enable=1, varname=f"learn_{i}", **hide,
                saved_attribute_attributes=param(f"Learn {i + 1}", 2, parameter_enum=["val1", "val2"], parameter_invisible=2))
    p = obj(f"prepend learn {i}", [745, py, 95, 22]); wire(learn, p); wire(p, js)
    box("live.comment", [850, py, 60, 18], [x + 80, y + 4, 112, 20], text="—", textjustification=0, fontsize=FS, varname=f"src_{i}", **hide)
    mapb = box("live.text", [915, py, 32, 16], [x + 196, y, 60, 26], numoutlets=2, outlettype=["", ""], mode=0, fontsize=FS,
               text="Map", texton="Map", parameter_enable=1, varname=f"map_{i}", **hide,
               saved_attribute_attributes=param(f"Map {i + 1}", 2, parameter_enum=["val1", "val2"], parameter_invisible=2))
    s = obj("route bang 1", [950, py, 40, 22], numoutlets=3, outlettype=["", "", ""]); wire(mapb, s)
    m = box("message", [995, py, 50, 22], None, text=f"map {i}", numinlets=2, numoutlets=1, outlettype=[""]); wire(s, m); wire(s, m, 1); wire(m, js)
    box("live.comment", [1050, py, 120, 18], [x + 262, y + 4, 244, 20], text="—", textjustification=0, fontsize=FS, varname=f"dst_{i}", **hide)
    for name, dx, initial in (("min", 510, 0), ("max", 572, 100)):
        # parameter_invisible 1: saved with the set, but not offered to control surfaces or automation,
        # so a controller steering "the selected device" cannot move these by accident.
        nb = box("live.numbox", [1175 + (40 if name == "max" else 0), py, 36, 15], [x + dx, y + 2, 56, 22], numoutlets=2, fontsize=FS,
                 outlettype=["", "float"], parameter_enable=1, varname=f"{name}_{i}", **hide,
                 saved_attribute_attributes=param(f"{name.title()} {i + 1}", 0, parameter_mmin=0.0, parameter_mmax=100.0,
                                                  parameter_initial_enable=1, parameter_initial=[initial], parameter_unitstyle=5,
                                                  parameter_invisible=1))
        p = obj(f"prepend {name} {i}", [1260 + (100 if name == "max" else 0), py, 90, 22]); wire(nb, p); wire(p, js)
    clr = box("live.text", [1460, py, 16, 16], [x + 634, y, 24, 26], numoutlets=2, outlettype=["", ""], mode=0, fontsize=FS,
              text="×", texton="×", parameter_enable=1, varname=f"clear_{i}", **hide,
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
