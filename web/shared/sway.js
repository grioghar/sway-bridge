// Shared client for the Sway bridge: one reconnecting WebSocket, state + MIDI events,
// request/response commands, and helpers that turn raw MIDI into "which control moved".

export const MODES = ['Modulation', 'Instrument', 'Trigger'];
export const SCALES = ['Major', 'Minor', 'Dorian', 'Phrygian', 'Lydian', 'Mixolydian', 'Locrian', 'Chromatic', 'Custom'];
export const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
export const FIELD_WIDTH = 41.43;   // region coordinate space
export const FIELD_DEPTH = 36;
export const LED_COUNT = 80;
export const PRESETS_PER_BANK = 6;

/** JSON with sorted keys, for comparing two values regardless of key order. */
export const canonical = (v) => JSON.stringify(v, (_, x) =>
  x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.keys(x).sort().map((k) => [k, x[k]])) : x);

export const noteName = (n) => `${NOTE_NAMES[n % 12]}${Math.floor(n / 12) - 1}`;

export class SwayLink extends EventTarget {
  state = null;
  #ws = null;
  #nextId = 1;
  #pending = new Map();

  constructor(url = `ws://${location.host || 'localhost:7729'}/ws`) {
    super();
    this.url = url;
    this.#connect();
  }

  #connect() {
    const ws = new WebSocket(this.url);
    this.#ws = ws;
    ws.onopen = () => this.dispatchEvent(new Event('open'));
    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.type === 'midi') this.dispatchEvent(new CustomEvent('midi', { detail: msg.m }));
      else if (msg.type === 'state') { this.state = msg.state; this.dispatchEvent(new CustomEvent('state', { detail: msg.state })); }
      else if (msg.type === 'result') {
        const p = this.#pending.get(msg.id);
        this.#pending.delete(msg.id);
        if (p) msg.error ? p.reject(new Error(msg.error)) : p.resolve(msg.result);
      }
    };
    ws.onclose = () => {
      for (const p of this.#pending.values()) p.reject(new Error('bridge disconnected'));
      this.#pending.clear();
      this.dispatchEvent(new Event('close'));
      setTimeout(() => this.#connect(), 1500);
    };
  }

  call(method, params = {}) {
    return new Promise((resolve, reject) => {
      if (this.#ws?.readyState !== 1) return reject(new Error('bridge is not running'));
      const id = this.#nextId++;
      this.#pending.set(id, { resolve, reject });
      this.#ws.send(JSON.stringify({ id, method, params }));
    });
  }

  /** The preset currently selected on the hardware, or null. */
  get activePreset() {
    const s = this.state;
    if (!s?.project || !s.selection) return null;
    return s.project.presets[s.selection.bank * PRESETS_PER_BANK + s.selection.preset] ?? null;
  }
}

/**
 * Build a lookup from MIDI message -> control for one preset, so a page can ask
 * "what did this message come from?". Returns { lookup(m) -> hit | null }.
 *
 * hit = { kind: 'pad', index, on, velocity }
 *     | { kind: 'dial', index, page, value }
 *     | { kind: 'region', index, role, value }      role: x | y | sway | pulse | press | note
 */
export function buildMidiMap(preset) {
  const cc = new Map();     // "ch:cc" -> hit template
  const note = new Map();   // "ch:note" -> [hit template]
  const add = (map, key, hit) => { if (!map.has(key)) map.set(key, []); map.get(key).push(hit); };

  if (preset) {
    preset.encoders.ccNumbers.forEach((row, page) => row.forEach((num, index) => {
      add(cc, `${preset.encoders.channels[page][index]}:${num}`, { kind: 'dial', index, page });
    }));
    preset.pads.rootNotes.forEach((root, index) => {
      add(note, `${preset.pads.channels[index]}:${preset.pads.rootOctaves[index] * 12 + root}`, { kind: 'pad', index });
    });
    preset.regions.slice(0, preset.regionCount).forEach((r, index) => {
      // Region CCs carry no channel in the preset data we can name yet, so match on any channel.
      const roles = { x: [r.ccX, r.ccX2], y: [r.ccY, r.ccY2], sway: [r.swayCc], pulse: [r.pulseCc], press: [r.pressCc] };
      for (const [role, nums] of Object.entries(roles)) {
        for (const n of new Set(nums.filter((v) => v != null))) add(cc, `*:${n}`, { kind: 'region', index, role });
      }
      r.notes.forEach((n, i) => add(note, `${r.noteChannels[i] ?? 0}:${n}`, { kind: 'region', index, role: 'note' }));
    });
  }

  return {
    lookup(m) {
      const type = m[0] & 0xf0, ch = m[0] & 0x0f;
      if (type === 0xb0) {
        // An exact dial match on (channel, cc) wins; region CCs match on number alone.
        const exact = cc.get(`${ch}:${m[1]}`), any = cc.get(`*:${m[1]}`);
        const hits = any && !exact ? any : exact ?? any;
        return hits ? hits.map((h) => ({ ...h, value: m[2] })) : null;
      }
      if (type === 0x90 || type === 0x80) {
        const hits = note.get(`${ch}:${m[1]}`);
        const on = type === 0x90 && m[2] > 0;
        return hits ? hits.map((h) => ({ ...h, on, velocity: m[2], note: m[1] })) : null;
      }
      return null;
    },
  };
}

/** Synthetic performance for layout checks and stream setup (overlay ?demo=1). */
export function startDemo(emit, preset) {
  let t = 0;
  const regions = preset?.regions.slice(0, preset.regionCount) ?? [];
  const timer = setInterval(() => {
    t += 1;
    const r = regions[Math.floor(t / 40) % Math.max(1, regions.length)];
    const wave = (speed, phase = 0) => Math.round(63.5 + 63.5 * Math.sin(t * speed + phase));
    if (r) {
      if (r.ccX != null) emit([0xb0, r.ccX, r.mode === 2 ? 127 : wave(0.11)]);
      if (r.ccY != null) emit([0xb0, r.ccY, wave(0.07, 1)]);
      if (r.notes.length && t % 40 === 1) emit([0x90 | (r.noteChannels[0] ?? 0), r.notes[0], 90]);
      if (r.notes.length && t % 40 === 30) emit([0x80 | (r.noteChannels[0] ?? 0), r.notes[0], 0]);
    }
    if (preset && t % 6 === 0) {
      const d = Math.floor(t / 30) % 8;
      emit([0xb0 | preset.encoders.channels[0][d], preset.encoders.ccNumbers[0][d], wave(0.05, d)]);
    }
    if (preset && t % 14 === 0) {
      const p = Math.floor(t / 14) % 16;
      const n = preset.pads.rootOctaves[p] * 12 + preset.pads.rootNotes[p];
      emit([0x90 | preset.pads.channels[p], n, 90]);
      setTimeout(() => emit([0x80 | preset.pads.channels[p], n, 0]), 220);
    }
  }, 33);
  return () => clearInterval(timer);
}
