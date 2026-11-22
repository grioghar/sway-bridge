// Sway Map — mapping engine for the Max for Live device.
// Each slot links one incoming MIDI CC (channel + number, learned from the Sway) to
// one Live parameter (whatever was last clicked in Live), scaled between Min and Max.
//
// Written for Max's classic [js] object (ES5). Talks to the UI through scripting names:
//   src_N / dst_N   comments showing the source CC and the target parameter
//   learn_N         live.text toggle
//   min_N / max_N   live.numbox (percent)
//   remote_N        live.remote~ that drives the target
//   mapstate        pattr blob that Live saves with the set

autowatch = 1;
inlets = 1;
outlets = 1;

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

function init() {
    try {
        ready = true;
        for (var i = 0; i < SLOTS; i++) refresh(i);
        if (pendingRestore) { applyRestore(pendingRestore); pendingRestore = null; }
        status("Ready — Learn a control, click a Live parameter, then Map");
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

/** Map slot i to the parameter currently selected in Live (the last one clicked). */
function map(i) {
    if (!ready) { status("Live is not ready yet"); return; }
    try {
        var sel = new LiveAPI("live_set view selected_parameter");
        if (!sel || sel.id == 0) { status("Click a parameter in Live first, then Map"); return; }
        attach(i, sel);
        persist();
        status("Slot " + (i + 1) + " → " + slots[i].name);
    } catch (e) { status("map failed: " + e); }
}

function attach(i, api) {
    var s = slots[i];
    s.id = parseInt(api.id, 10);
    s.path = api.unquotedpath;
    s.pmin = parseFloat(api.get("min"));
    s.pmax = parseFloat(api.get("max"));
    var owner = new LiveAPI(api.unquotedpath.replace(/ parameters \d+$/, ""));
    var ownerName = owner && owner.id != 0 ? String(owner.get("name")) : "";
    s.name = (ownerName ? ownerName + " · " : "") + String(api.get("name"));
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
