// App state: owns the bridge (serial link, MIDI, overlay server) and the preset being edited.
import SwiftUI
import SwayKit
import SwayBridgeCore

struct Slot: Hashable {
    var bank: Int
    var preset: Int
    var index: Int { bank * SwayLayout.presetsPerBank + preset }
}

/// A control on the Sway that can be selected for editing.
enum Control: Hashable {
    case region(Int)
    case pad(Int)
    case dial(Int)
    case button(Int)
}

struct Notice: Equatable {
    var text: String
    var isError = false
}

final class AppModel: ObservableObject {
    static let port = 7729

    @Published private(set) var state = BridgeState()
    @Published private(set) var open: Slot?        // preset shown in the editor
    @Published var draft: Preset? { didSet { updateMap() } }
    @Published var selected: Control = .region(0)
    /// Index of the selected region (0 when another kind of control is selected).
    var region: Int {
        get { if case .region(let i) = selected { return i } else { return 0 } }
        set { selected = .region(newValue) }
    }
    @Published var notice: Notice?
    @Published var busy = false
    @Published var startupError: String?
    @Published var brightness: Double = 0
    @Published var pendingSlot: Slot?              // waiting for "discard changes?"
    @Published var confirmReload = false

    let feed = LiveFeed()
    var brightnessEditing = false
    private var follow = true                      // keep the editor on the preset active on the Sway
    private var bridge: Bridge?
    private var noticeTimer: Timer?

    init() {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("web")
        let webRoot = bundled.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("web")
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sway Bridge")
        let server = WebServer(port: AppModel.port, webRoot: webRoot)
        do { try server.start() } catch {
            startupError = "The OBS overlay is unavailable: \(error)"
        }
        let bridge = Bridge(server: server, backups: support.appendingPathComponent("backups"))
        let feed = self.feed
        bridge.onState = { [weak self] new in DispatchQueue.main.async { self?.apply(new) } }
        bridge.onMIDI = { [weak feed] message in feed?.push(message) }
        bridge.start()
        self.bridge = bridge
    }

    // MARK: - derived

    var selection: Slot? { state.selection.map { Slot(bank: $0.bank, preset: $0.preset) } }

    var stored: Preset? {
        guard let open, let project = state.project, project.presets.indices.contains(open.index) else { return nil }
        return project.presets[open.index]
    }

    var isDirty: Bool {
        guard let draft, let stored else { return false }
        return draft != stored
    }

    var statusText: String {
        guard state.connected, let device = state.device else { return "Sway not connected" }
        return "Sway connected · firmware \(device.firmware)" + (device.lowPower ? " · low-power mode" : "")
            + (state.midiConnected ? "" : " · no MIDI")
    }

    func presetName(_ slot: Slot) -> String {
        guard let project = state.project, project.presets.indices.contains(slot.index) else { return "" }
        let name = project.presets[slot.index].name
        return name.isEmpty ? "(unnamed)" : name
    }

    // MARK: - state from the bridge

    private func apply(_ new: BridgeState) {
        state = new
        if let value = new.device?.brightness, !brightnessEditing { brightness = Double(value) }
        if new.project != nil, !isDirty {
            // Follow the hardware's active preset unless another one was picked for editing.
            if let live = selection, follow || open == nil, open != live { open = live; region = 0 }
            if open != nil { draft = stored }
        }
        clampRegion()
        updateMap()
    }

    /// Live MIDI only describes the preset active on the hardware.
    private func updateMap() {
        feed.map = MIDIMap(open != nil && open == selection ? draft : nil)
    }

    private func clampRegion() {
        let count = min(draft?.regionCount ?? 0, draft?.regions.count ?? 0)
        if case .region(let i) = selected, i >= count { selected = .region(max(0, count - 1)) }
    }

    // MARK: - editing

    /// Binding to the whole draft that stays valid while views are torn down.
    var draftBinding: Binding<Preset>? {
        guard let snapshot = draft else { return nil }
        return Binding(get: { [weak self] in self?.draft ?? snapshot },
                       set: { [weak self] in if self?.draft != nil { self?.draft = $0 } })
    }

    var regionBinding: Binding<Region>? {
        guard case .region = selected, let draft, draft.regions.indices.contains(region) else { return nil }
        let index = region, snapshot = draft.regions[index]
        return Binding(get: { [weak self] in
            if let d = self?.draft, d.regions.indices.contains(index) { return d.regions[index] }
            return snapshot
        }, set: { [weak self] new in
            guard let self, let d = self.draft, d.regions.indices.contains(index) else { return }
            var new = new
            // The preset stores the X and Y CCs twice; keep the second copy in step when one is edited.
            if new.ccX != d.regions[index].ccX { new.ccX2 = new.ccX }
            if new.ccY != d.regions[index].ccY { new.ccY2 = new.ccY }
            self.draft?.regions[index] = new
        })
    }

    func setName(_ text: String) {
        guard draft != nil else { return }
        var bytes = Array(text.utf8.prefix(19))
        while String(bytes: bytes, encoding: .utf8) == nil { bytes.removeLast() }   // don't split a character
        let name = String(decoding: bytes, as: UTF8.self)
        draft?.name = name
        // Keep the original name bytes when the name is back to what the Sway has.
        draft?.nameRaw = name == stored?.name ? stored?.nameRaw : nil
    }

    func choose(_ slot: Slot) {
        guard slot != open else { return }
        if isDirty { pendingSlot = slot } else { show(slot) }
    }

    func discardAndShowPending() {
        if let slot = pendingSlot { show(slot) }
        pendingSlot = nil
    }

    private func show(_ slot: Slot) {
        follow = slot == selection
        open = slot
        region = 0
        draft = stored
        updateMap()
    }

    func revert() {
        draft = stored
        clampRegion()
    }

    // MARK: - device actions

    func reload(force: Bool = false) {
        if isDirty && !force { confirmReload = true; return }
        guard let bridge, !busy else { return }
        busy = true
        draft = stored
        bridge.reload { [weak self] error in
            DispatchQueue.main.async {
                self?.busy = false
                self?.say(error.map { "\($0)" } ?? "Reloaded from the Sway.", isError: error != nil)
            }
        }
    }

    func send() {
        guard let bridge, let open, let draft, isDirty, state.connected, !busy else { return }
        busy = true
        bridge.writePreset(bank: open.bank, preset: open.preset, draft) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                if let error {
                    self.say("Not sent: \(error)", isError: true)
                } else {
                    self.follow = true
                    self.draft = self.stored
                    self.say("Sent to bank \(open.bank + 1), preset \(open.preset + 1) and verified by reading it back.")
                }
            }
        }
    }

    func commitBrightness() {
        guard let bridge, state.connected else { return }
        bridge.setBrightness(Int(brightness.rounded())) { [weak self] error in
            guard let error else { return }
            DispatchQueue.main.async { self?.say("\(error)", isError: true) }
        }
    }

    func say(_ text: String, isError: Bool = false) {
        notice = Notice(text: text, isError: isError)
        noticeTimer?.invalidate()
        noticeTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in self?.notice = nil }
    }
}

// MARK: - helpers shared by the views

let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

func noteName(_ note: Int) -> String { "\(noteNames[((note % 12) + 12) % 12])\(note / 12 - 1)" }

/// "C3", "F#4", "Bb2" or a number 0–127.
func parseNote(_ text: String) -> Int? {
    if let number = Int(text) { return (0...127).contains(number) ? number : nil }
    var rest = Substring(text)
    guard let letter = rest.popFirst(), let base = noteNames.firstIndex(of: String(letter).uppercased()) else { return nil }
    var note = base
    if rest.first == "#" { note += 1; rest.removeFirst() } else if rest.first == "b" { note -= 1; rest.removeFirst() }
    guard let octave = Int(rest), (-1...9).contains(octave) else { return nil }
    note += (octave + 1) * 12
    return (0...127).contains(note) ? note : nil
}

extension Color {
    init(hex: String) {
        let digits = hex.drop { $0 == "#" }
        let value = UInt32(digits, radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255,
                  blue: Double(value & 0xff) / 255, opacity: 1)
    }

    var hex: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        func byte(_ v: CGFloat) -> Int { Int((min(1, max(0, v)) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", byte(c.redComponent), byte(c.greenComponent), byte(c.blueComponent))
    }
}
