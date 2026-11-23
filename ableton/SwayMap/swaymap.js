// Sway Map — mapping engine for the Max for Live device.
// Each slot links one incoming MIDI CC (channel + number, learned from the Sway) to
// one Live parameter (whatever was last clicked in Live), scaled between Min and Max.
//
// Written for Max's classic [js] object (ES5). Talks to the UI through scripting names:
//   src_N / dst_N   comments showing the source CC and the target parameter
//   learn_N         live.text toggle
//   min_N / max_N   live.numbox (percent)
//   remote_N        live.remote~ that drives the target
//   num_N           row number; all of a row is shown or hidden by page()
//   mapstate        pattr blob that Live saves with the set

autowatch = 1;
inlets = 1;
outlets = 2;          // 0: pitch velocity, 1: channel (sent first) — notes moved onto Live's scale

var SLOTS = 16;
var slots = [];          // { ch, cc, id, path, name, pmin, pmax, lo, hi }
var learning = -1;
var ready = false;       // LiveAPI is only usable after live.thisdevice fires
var pendingRestore = null;
var lastSaved = "";

for (var i = 0; i < SLOTS; i++) slots.push(blank());

function blank() { return { ch: -1, cc: -1, id: 0, path: "", name: "", pmin: 0, pmax: 1, lo: 0, hi: 100 }; }
function named(n) { return this.patcher.getnamed(n); }
function say(n, text) { var o = named(n); if (o) o.message("set", text); }

function refresh(i) {
    var s = slots[i];
    say("src_" + i, s.cc < 0 ? "—" : "CC " + s.cc + " ch " + (s.ch + 1));
    say("dst_" + i, s.id ? s.name : "—");
}

// ---- lifecycle ----

function status(text) { say("status", text); }

// ---- pages: PER_PAGE rows are shown at a time so the text can be large ----
var PER_PAGE = 4;
var PARTS = ["num_", "learn_", "src_", "map_", "dst_", "min_", "max_", "clear_"];

function page(p) {
    for (var i = 0; i < SLOTS; i++) {
        var off = Math.floor(i / PER_PAGE) !== p;
        for (var k = 0; k < PARTS.length; k++) { var o = named(PARTS[k] + i); if (o) o.hidden = off; }
    }
}

function init() {
    try {
        ready = true;
        for (var i = 0; i < SLOTS; i++) refresh(i);
        if (pendingRestore) { applyRestore(pendingRestore); pendingRestore = null; }
        status("Ready. Learn → Map → click a parameter");
    } catch (e) { status("init failed: " + e); }
}

// ---- MIDI in: "cc <number> <value> <channel 1-16>" ----

function cc(number, value, channel) {
    var ch = channel - 1;
    if (learning >= 0) {
        var s = slots[learning];
        s.ch = ch; s.cc = number;
        status("Slot " + (learning + 1) + " learned CC " + number + " on channel " + channel);
        var o = named("learn_" + learning);
        if (o) o.message("set", 0);
        refresh(learning);
        learning = -1;
        persist();
        return;
    }
    for (var i = 0; i < SLOTS; i++) {
        var m = slots[i];
        if (m.id && m.cc === number && m.ch === ch) {
            var x = (m.lo + (m.hi - m.lo) * (value / 127)) / 100;
            var r = named("remote_" + i);
            if (r) r.message("float", m.pmin + x * (m.pmax - m.pmin));
        }
    }
}

// ---- UI ----

function learn(i, on) {
    if (learning >= 0 && learning !== i) { var o = named("learn_" + learning); if (o) o.message("set", 0); }
    learning = on ? i : -1;
    status(on ? "Move a control on the Sway…" : "Learn cancelled");
}

/** Map slot i: press Map, then click the parameter in Live. The next parameter that becomes
 *  selected is taken. (Reading the selection at the moment of the press does not work: pressing
 *  a button in this device clears Live's selected parameter.) Press Map again to cancel. */
var mapping = -1;
var poller = null;
var polls = 0;

function map(i) {
    if (mapping === i) { stopPicking(); status("Map cancelled"); return; }
    mapping = i;
    polls = 0;
    if (!poller) poller = new Task(pick, this);
    poller.interval = 100;
    poller.repeat();
    status("Slot " + (i + 1) + ": click a parameter in Live…");
}

function stopPicking() {
    mapping = -1;
    if (poller) poller.cancel();
}

/** Runs ten times a second while a slot is waiting for its parameter (gives up after 30 s). */
function pick() {
    if (mapping < 0) { stopPicking(); return; }
    polls++;
    if (polls < 3) return;            // let the Map press itself settle
    if (polls > 300) { stopPicking(); status("Map timed out. Press Map again."); return; }
    try {
        var sel = new LiveAPI("live_set view selected_parameter");
        if (!sel || sel.id == 0) return;
        var i = mapping;
        stopPicking();
        attach(i, sel);
        persist();
        status("Slot " + (i + 1) + " → " + slots[i].name);
    } catch (e) { stopPicking(); status("map failed: " + e); }
}

function attach(i, api) {
    var s = slots[i];
    s.id = parseInt(api.id, 10);
    s.path = api.unquotedpath;
    s.pmin = parseFloat(api.get("min"));
    s.pmax = parseFloat(api.get("max"));
    // Name it after its device, or after its track when it is a mixer control (volume, pan, send).
    var ownerPath = /mixer_device/.test(s.path) ? s.path.replace(/ mixer_device.*$/, "") : s.path.replace(/ parameters \d+$/, "");
    var owner = ownerPath !== s.path ? new LiveAPI(ownerPath) : null;
    var ownerName = owner && owner.id != 0 ? String(owner.get("name")) : "";
    var own = String(api.get("name")).replace(/^Track /, "");
    s.name = (ownerName ? ownerName + " · " : "") + own;
    var r = named("remote_" + i);
    if (r) r.message("id", s.id);
    refresh(i);
}

function clear(i) {
    var r = named("remote_" + i);
    if (r) r.message("id", 0);
    slots[i] = blank();
    var lo = named("min_" + i), hi = named("max_" + i);
    if (lo) lo.message("set", 0);
    if (hi) hi.message("set", 100);
    refresh(i);
    persist();
}

function min(i, v) { slots[i].lo = v; }
function max(i, v) { slots[i].hi = v; }

// ---- persistence: a flat list of plain atoms, saved by Live with the set ----
// slot, channel, cc, path-token-count, path tokens...   (only slots that have anything set)

function persist() {
    var out = [];
    for (var i = 0; i < SLOTS; i++) {
        var s = slots[i];
        if (s.cc < 0 && !s.id) continue;
        var tokens = s.path ? s.path.split(" ") : [];
        out.push(i, s.ch, s.cc, tokens.length);
        for (var t = 0; t < tokens.length; t++) out.push(isNaN(tokens[t]) ? tokens[t] : parseInt(tokens[t], 10));
    }
    if (!out.length) out = ["empty"];
    lastSaved = out.join(" ");
    var p = named("mapstate");
    if (p) p.message(out);
}

function restore() {
    var a = arrayfromargs(arguments);
    if (a.join(" ") === lastSaved) return;      // our own write coming back
    if (ready) applyRestore(a); else pendingRestore = a;
}

function applyRestore(a) {
    if (a[0] === "empty") return;
    var k = 0;
    while (k + 3 < a.length) {
        var i = a[k], ch = a[k + 1], number = a[k + 2], n = a[k + 3];
        var path = a.slice(k + 4, k + 4 + n).join(" ");
        k += 4 + n;
        if (i < 0 || i >= SLOTS) continue;
        slots[i].ch = ch; slots[i].cc = number;
        if (path) {
            var api = new LiveAPI(path);
            if (api && api.id != 0) attach(i, api);
            else { slots[i].path = path; say("dst_" + i, "(target missing)"); }
        }
        refresh(i);
    }
    lastSaved = a.join(" ");
}


// ---- follow Live's scale ----
// With the switch on, every note played is moved to the nearest note of the scale set in Live
// (Live 12: the key and scale in the control bar). A note keeps the pitch it started with until
// it is released, so changing scale while holding a note never leaves one hanging.

var following = 0;
var scaleTable = null;     // input pitch -> output pitch
var scaleSig = "";
var held = {};             // channel * 128 + played pitch -> pitch that was sent
var scaleTask = null;

function follow(on) {
    following = on ? 1 : 0;
    if (following) {
        readScale(true);
        if (!scaleTask) scaleTask = new Task(readScale, this);
        scaleTask.interval = 500;
        scaleTask.repeat();
    } else {
        if (scaleTask) scaleTask.cancel();
        // Release anything still sounding at a moved pitch; from now on MIDI bypasses this script.
        for (var k in held) { var key = parseInt(k, 10); outlet(1, Math.floor(key / 128) + 1); outlet(0, held[k], 0); }
        held = {};
        status("Notes: as played");
    }
}

/** Reads the key and scale from Live (twice a second while the switch is on) and rebuilds the table when they change. */
function readScale(announce) {
    try {
        var song = new LiveAPI("live_set");
        var root = parseInt(song.get("root_note"), 10);
        var steps = song.get("scale_intervals");
        if (isNaN(root) || !steps || !steps.length) { if (announce === true) status("This Live version has no scale to follow"); return; }
        var sig = root + ":" + steps.join(",");
        if (sig === scaleSig && scaleTable) { if (announce === true) announceScale(song, root); return; }
        var inScale = [];
        for (var i = 0; i < 12; i++) inScale.push(false);
        for (var s = 0; s < steps.length; s++) inScale[(root + parseInt(steps[s], 10)) % 12] = true;
        var table = [];
        for (var p = 0; p < 128; p++) {
            var best = p;
            for (var d = 0; d < 7; d++) {                 // nearest scale note; a tie goes down
                if (p - d >= 0 && inScale[(p - d) % 12]) { best = p - d; break; }
                if (p + d <= 127 && inScale[(p + d) % 12]) { best = p + d; break; }
            }
            table.push(best);
        }
        scaleTable = table;
        scaleSig = sig;
        announceScale(song, root);
    } catch (e) { status("scale read failed: " + e); }
}

function announceScale(song, root) {
    var names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    status("Notes follow Live: " + names[root % 12] + " " + String(song.get("scale_name")));
}

function note(pitch, velocity, channel) {
    var key = (channel - 1) * 128 + pitch, out;
    if (velocity > 0) {
        out = scaleTable ? scaleTable[pitch] : pitch;
        held[key] = out;
    } else {
        out = held[key] !== undefined ? held[key] : (scaleTable ? scaleTable[pitch] : pitch);
        delete held[key];
    }
    outlet(1, channel);
    outlet(0, out, velocity);
}
