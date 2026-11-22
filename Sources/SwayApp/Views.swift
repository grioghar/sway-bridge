import SwiftUI
import SwayKit

// MARK: - window

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            PresetList()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
        } detail: {
            VStack(spacing: 0) {
                StatusBar()
                Divider()
                if let draft = model.draftBinding {
                    Editor(draft: draft)
                } else {
                    Placeholder()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if model.busy { ProgressView().controlSize(.small) }
                if model.isDirty { Text("Unsent changes").foregroundStyle(.orange).font(.callout) }
                Button("Switch Sway to This Preset") { model.activate() }
                    .disabled(!model.state.connected || model.busy || model.open == nil || model.open == model.selection)
                    .help("Make the preset shown here the active one on the Sway")
                Button("Reload") { model.reload() }
                    .disabled(!model.state.connected || model.busy)
                    .help("Read everything from the Sway again")
                Button("Revert") { model.revert() }
                    .disabled(!model.isDirty)
                Button("Send to Sway") { model.send() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.isDirty || !model.state.connected || model.busy)
                    .help("Store this preset on the Sway and read it back to verify")
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                Text(notice.text)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(notice.isError ? Color.red.opacity(0.9) : Color.green.opacity(0.85), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.notice)
        .confirmationDialog("Discard unsent changes to this preset?", isPresented: Binding(
            get: { model.pendingSlot != nil }, set: { if !$0 { model.pendingSlot = nil } })) {
            Button("Discard Changes", role: .destructive) { model.discardAndShowPending() }
            Button("Cancel", role: .cancel) { model.pendingSlot = nil }
        }
        .confirmationDialog("Discard unsent changes and reload everything from the Sway?", isPresented: $model.confirmReload) {
            Button("Discard and Reload", role: .destructive) { model.reload(force: true) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct Placeholder: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "cable.connector").font(.system(size: 40)).foregroundStyle(.secondary)
            Text(model.state.connected ? "Reading presets…" : "Connect the Sway over USB").font(.title3)
            Text("Quit Audima's own app first: both need the same serial port.").foregroundStyle(.secondary)
            HelpMenuItem().buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StatusBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(model.state.connected ? Color.green : Color.red).frame(width: 9, height: 9)
                Text(model.statusText)
                Spacer()
                Text("Brightness").foregroundStyle(.secondary)
                Slider(value: $model.brightness, in: 0...100) { editing in
                    model.brightnessEditing = editing
                    if !editing { model.commitBrightness() }
                }
                .frame(width: 160)
                .disabled(!model.state.connected)
            }
            ForEach([model.state.error, model.startupError].compactMap { $0 }, id: \.self) { message in
                Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }
}

// MARK: - sidebar

struct PresetList: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        List(selection: Binding(get: { model.open }, set: { if let slot = $0 { model.choose(slot) } })) {
            if model.state.project != nil {
                ForEach(0..<6, id: \.self) { bank in
                    Section("Bank \(bank + 1)") {
                        // Rows are identified by slot: ids must be unique across the whole list.
                        ForEach((0..<SwayLayout.presetsPerBank).map { Slot(bank: bank, preset: $0) }, id: \.self) { slot in
                            HStack {
                                Text("\(slot.preset + 1)").monospacedDigit().foregroundStyle(.secondary)
                                Text(model.presetName(slot)).lineLimit(1)
                                Spacer()
                                if model.selection == slot {
                                    Circle().fill(.green).frame(width: 8, height: 8).help("Active on the Sway")
                                }
                            }
                            .tag(slot)
                            .contextMenu {
                                Button("Switch Sway to This Preset") { model.activate(slot) }
                                    .disabled(!model.state.connected || model.selection == slot)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - editor

struct Editor: View {
    @EnvironmentObject var model: AppModel
    @Binding var draft: Preset
    @State private var dialPage = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TextField("Preset name", text: Binding(get: { draft.name }, set: { model.setName($0) }))
                        .textFieldStyle(.roundedBorder).font(.title3).frame(maxWidth: 320)
                    Picker("Scale", selection: $draft.scale) {
                        ForEach(SwayLayout.scales.indices, id: \.self) { Text(SwayLayout.scales[$0]).tag($0) }
                        if !SwayLayout.scales.indices.contains(draft.scale) { Text("Scale \(draft.scale)").tag(draft.scale) }
                    }
                    .frame(maxWidth: 220)
                    Picker("Dial page", selection: $dialPage) {
                        ForEach(0..<8, id: \.self) { Text(pageName($0)).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(maxWidth: 330)
                    Spacer()
                    if let open = model.open, model.selection != open {
                        Text("Not the active preset: live levels are off").foregroundStyle(.secondary)
                    }
                }
                DeviceView(preset: draft, open: model.open, active: model.selection, selected: $model.selected,
                           dialPage: $dialPage, feed: model.feed) { preset in
                    if let bank = model.open?.bank { model.choose(Slot(bank: bank, preset: preset)) }
                }
                ControlInspector(draft: $draft, dialPage: $dialPage)
                    .id("\(model.open?.index ?? -1)-\(model.selected)")
            }
            .padding(16)
        }
    }
}

struct RegionBox: View {
    let region: Region
    let index: Int
    let isSelected: Bool
    let isHot: Bool
    let hand: LiveFeed.Hand?

    private var summary: String {
        if region.mode == 1 {
            return region.notes.isEmpty ? "no notes" : region.notes.prefix(5).map(noteName).joined(separator: " ")
        }
        let parts = [region.ccX.map { "\(region.mode == 2 ? "Trig" : "X") \($0)" }, region.ccY.map { "Y \($0)" }].compactMap { $0 }
        return parts.isEmpty ? "unassigned" : parts.joined(separator: " · ")
    }

    var body: some View {
        let start = Color(hex: region.colorStart)
        let end = region.colorEnd == "#000000" ? start : Color(hex: region.colorEnd)
        let mode = SwayLayout.modes.indices.contains(region.mode) ? SwayLayout.modes[region.mode] : "Mode \(region.mode)"
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [start.opacity(isHot ? 0.75 : 0.4), end.opacity(isHot ? 0.65 : 0.33)], startPoint: .bottom, endPoint: .top)
            GeometryReader { geo in
                if let hand {
                    // Hand height as a line, sideways position as a bead on it.
                    let y = geo.size.height * (1 - CGFloat(hand.y ?? 0) / 127)
                    if hand.y != nil { Rectangle().fill(.white.opacity(0.9)).frame(height: 2).offset(y: y - 1) }
                    if let x = hand.x {
                        Circle().fill(.white).frame(width: 9, height: 9)
                            .offset(x: (geo.size.width - 9) * CGFloat(region.invertX ? 127 - x : x) / 127, y: (hand.y == nil ? geo.size.height / 2 : y) - 4.5)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("R\(index + 1) · \(mode)").bold()
                Text(summary)
            }
            .font(.caption).foregroundStyle(.white).shadow(radius: 2).padding(5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(isSelected ? Color.white : start, lineWidth: isSelected ? 2.5 : 1))
        .contentShape(Rectangle())
    }
}

// MARK: - region inspector

struct Inspector: View {
    @Binding var region: Region
    let index: Int
    let count: Int
    @State private var notesText = ""
    @State private var notesError: String?

    var body: some View {
        GroupBox("Region \(index + 1) of \(count)") {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 7) {
                row("Mode") {
                    Picker("", selection: $region.mode) {
                        ForEach(SwayLayout.modes.indices, id: \.self) { Text(SwayLayout.modes[$0]).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented)
                }
                if region.mode == 1 {
                    row("Notes") {
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("e.g. C3 E3 G3", text: $notesText)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(commitNotes)
                            if let notesError { Text(notesError).font(.caption).foregroundStyle(.red) }
                        }
                    }
                    row("Note channel") {
                        NumberField(value: Binding(get: { (region.noteChannels.first ?? 0) + 1 },
                                                   set: { v in region.noteChannels = region.notes.map { _ in (v ?? 1) - 1 } }), range: 1...16)
                    }
                }
                row(region.mode == 2 ? "Trigger CC" : "X CC") { NumberField(value: $region.ccX, optional: true) }
                row("Y CC") { NumberField(value: $region.ccY, optional: true) }
                row("Sway CC") { NumberField(value: $region.swayCc, optional: true) }
                row("Pulse CC") { NumberField(value: $region.pulseCc, optional: true) }
                row("Press CC") { NumberField(value: $region.pressCc, optional: true) }
                row("Strike threshold") {
                    TextField("off", value: Binding(get: { region.strikeThreshold.map(Double.init) },
                                                    set: { region.strikeThreshold = $0.map { Float(min(1, max(0, $0))) } }),
                              format: .number.precision(.fractionLength(0...2)))
                        .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 64)
                }
                row("Colours") {
                    HStack {
                        colour($region.colorStart)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        colour($region.colorEnd)
                    }
                }
                row("LEDs") {
                    HStack {
                        NumberField(value: $region.ledStart.optional, range: 0...SwayLayout.ledCount)
                        Text("to").foregroundStyle(.secondary)
                        NumberField(value: $region.ledEnd.optional, range: 0...SwayLayout.ledCount)
                    }
                }
                row("Invert horizontal axis") { Toggle("", isOn: $region.invertX).labelsHidden() }
                row("Clear CC on release") { Toggle("", isOn: $region.clearModulationOnRelease).labelsHidden() }
            }
            .padding(6)
        }
        .onAppear { notesText = region.notes.map(noteName).joined(separator: " ") }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            content()
        }
    }

    private func colour(_ hex: Binding<String>) -> some View {
        ColorPicker("", selection: Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = $0.hex }), supportsOpacity: false)
            .labelsHidden()
    }

    private func commitNotes() {
        let parsed = notesText.split(whereSeparator: { $0 == " " || $0 == "," }).map { parseNote(String($0)) }
        guard !parsed.contains(nil), parsed.count <= 15 else {
            notesError = "Use names like C3 or F#4, or numbers 0–127 (up to 15)."
            return
        }
        notesError = nil
        let notes = parsed.compactMap { $0 }
        let channels = region.noteChannels
        region.notes = notes
        region.noteCount = notes.count
        region.noteChannels = notes.indices.map { $0 < channels.count ? channels[$0] : (channels.first ?? 0) }
        if let first = notes.first { region.rootNote = first % 12; region.rootOctave = first / 12 }
        notesText = notes.map(noteName).joined(separator: " ")
    }
}

// MARK: - small pieces

/// A number box that clamps to `range`; with `optional`, clearing it means "off".
struct NumberField: View {
    @Binding var value: Int?
    var range: ClosedRange<Int> = 0...127
    var optional = false
    var hot = false

    var body: some View {
        TextField(optional ? "off" : "", value: Binding(get: { value }, set: { new in
            if let new { value = min(range.upperBound, max(range.lowerBound, new)) } else if optional { value = nil }
        }), format: .number.grouping(.never))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 58)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(hot ? 0.55 : 0)).padding(-3))
    }
}

extension Binding where Value == Int {
    /// For fields that edit a required number through the optional-number box.
    var optional: Binding<Int?> {
        Binding<Int?>(get: { wrappedValue }, set: { if let new = $0 { wrappedValue = new } })
    }
}
