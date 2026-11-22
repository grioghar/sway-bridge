import SwiftUI
import SwayKit

// MARK: - window

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("showAllPresets") private var showAll = false

    var body: some View {
        // A plain row rather than a split view: the preset column must never collapse or overlap.
        HStack(spacing: 0) {
            PresetList(showAll: $showAll)
                .frame(width: Metrics.sidebar)
                .frame(maxHeight: .infinity)
                .background(.regularMaterial)
            Divider()
            VStack(spacing: 0) {
                StatusBar().frame(minHeight: Metrics.statusBar)
                Divider()
                if showAll, model.state.project != nil {
                    PresetOverview(showAll: $showAll)
                } else if let draft = model.draftBinding {
                    Editor(draft: draft)
                } else {
                    Placeholder()
                }
            }
            .frame(minWidth: Metrics.detailWidth, minHeight: Metrics.detailHeight)
        }
        .toolbar {
            ToolbarItemGroup {
                if model.busy { ProgressView().controlSize(.small) }
                if model.isDirty { Text("Unsent changes").foregroundStyle(.orange).font(.callout) }
                Toggle(isOn: $showAll) { Label("All Presets", systemImage: "square.grid.3x3") }
                    .help("Show all 36 presets at once")
                Button("Switch Sway") { model.activate() }
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
        .padding(.horizontal, Metrics.pad).padding(.vertical, 6)
    }
}

// MARK: - sidebar

/// Compact preset picker: one bank at a time, chosen with the 1-6 strip, like the six buttons
/// on the Sway. The grid button opens the overview of all 36.
struct PresetList: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAll: Bool
    @State private var bank = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Bank").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { showAll.toggle() } label: { Image(systemName: "square.grid.3x3") }
                    .buttonStyle(.borderless)
                    .help("Show all 36 presets at once")
            }
            Picker("Bank", selection: $bank) {
                ForEach(0..<6, id: \.self) { Text("\($0 + 1)").tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()

            if model.state.project != nil {
                VStack(spacing: 2) {
                    ForEach((0..<SwayLayout.presetsPerBank).map { Slot(bank: bank, preset: $0) }, id: \.self) { slot in
                        PresetRow(slot: slot, isOpen: model.open == slot && !showAll)
                    }
                }
            }
            if let live = model.selection, live.bank != bank {
                Button("Active: bank \(live.bank + 1), preset \(live.preset + 1)") { bank = live.bank }
                    .buttonStyle(.link).font(.caption)
                    .help("Show the bank that is active on the Sway")
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .onAppear { bank = model.open?.bank ?? 0 }
        .onChange(of: model.open) { slot in if let slot { bank = slot.bank } }
    }
}

struct PresetRow: View {
    @EnvironmentObject var model: AppModel
    let slot: Slot
    let isOpen: Bool

    var body: some View {
        Button { model.choose(slot) } label: {
            HStack(spacing: 6) {
                Text("\(slot.preset + 1)").monospacedDigit().foregroundStyle(isOpen ? Color.white.opacity(0.8) : Color.secondary)
                Text(model.presetName(slot)).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
                if model.selection == slot { Circle().fill(.green).frame(width: 7, height: 7).help("Active on the Sway") }
            }
            .padding(.horizontal, 7).padding(.vertical, 4)
            .foregroundStyle(isOpen ? Color.white : Color.primary)
            .background(RoundedRectangle(cornerRadius: 5).fill(isOpen ? Color.accentColor : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Switch Sway to This Preset") { model.activate(slot) }
                .disabled(!model.state.connected || model.selection == slot)
        }
    }
}

/// Every preset at once: banks across, presets down. Click one to edit it.
struct PresetOverview: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAll: Bool

    var body: some View {
        ScrollView {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text("")
                    ForEach(0..<6, id: \.self) { Text("Bank \($0 + 1)").font(.headline) }
                }
                ForEach(0..<SwayLayout.presetsPerBank, id: \.self) { preset in
                    GridRow {
                        Text("\(preset + 1)").font(.headline).foregroundStyle(.secondary)
                        ForEach((0..<6).map { Slot(bank: $0, preset: preset) }, id: \.self) { slot in cell(slot) }
                    }
                }
            }
            .padding(16)
            Text("Click a preset to edit it. Right-click to switch the Sway to it. The green dot is the preset active on the Sway.")
                .font(.callout).foregroundStyle(.secondary).padding(.bottom, 16)
        }
    }

    private func cell(_ slot: Slot) -> some View {
        let isOpen = model.open == slot, isLive = model.selection == slot
        return Button {
            model.choose(slot)
            if model.pendingSlot == nil { showAll = false }
        } label: {
            HStack(alignment: .top, spacing: 4) {
                Text(model.presetName(slot)).font(.body).multilineTextAlignment(.leading).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if isLive { Circle().fill(.green).frame(width: 8, height: 8).padding(.top, 4) }
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(isOpen ? 0.14 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(isOpen ? Color.accentColor : Color.clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Switch Sway to This Preset") { model.activate(slot) }
                .disabled(!model.state.connected || isLive)
        }
    }
}

// MARK: - editor

struct Editor: View {
    @EnvironmentObject var model: AppModel
    @Binding var draft: Preset
    @State private var dialPage = 0

    var body: some View {
        // Everything is on screen at once: the drawing takes whatever room is left, and the window
        // cannot be made smaller than this layout needs (see Metrics).
        VStack(alignment: .leading, spacing: Metrics.gap) {
            HStack(spacing: 10) {
                TextField("Preset name", text: Binding(get: { draft.name }, set: { model.setName($0) }))
                    .textFieldStyle(.roundedBorder).frame(width: 190)
                Picker("Scale", selection: $draft.scale) {
                    ForEach(SwayLayout.scales.indices, id: \.self) { Text(SwayLayout.scales[$0]).tag($0) }
                    if !SwayLayout.scales.indices.contains(draft.scale) { Text("Scale \(draft.scale)").tag(draft.scale) }
                }
                .frame(width: 170)
                Picker("Dial page", selection: $dialPage) {
                    ForEach(0..<8, id: \.self) { Text(pageName($0)).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 290)
                Spacer(minLength: 0)
                if let open = model.open, model.selection != open {
                    Label("Live off", systemImage: "eye.slash").foregroundStyle(.secondary)
                        .help("This is not the preset active on the Sway, so live levels are not shown")
                }
            }
            .frame(height: Metrics.header)
            DeviceView(preset: draft, open: model.open, active: model.selection, selected: $model.selected,
                       dialPage: $dialPage, feed: model.feed) { preset in
                if let bank = model.open?.bank { model.choose(Slot(bank: bank, preset: preset)) }
            }
            .frame(minWidth: Metrics.deviceWidth, maxWidth: .infinity, minHeight: Metrics.deviceHeight, maxHeight: .infinity)
            ControlInspector(draft: $draft, dialPage: $dialPage)
                .id("\(model.open?.index ?? -1)-\(model.selected)")
                .frame(maxWidth: .infinity, minHeight: Metrics.inspector, maxHeight: Metrics.inspector, alignment: .topLeading)
        }
        .padding(Metrics.pad)
    }
}

/// Sizes the minimum window is derived from, so nothing is ever cut off.
enum Metrics {
    static let pad: CGFloat = 14
    static let gap: CGFloat = 10
    static let header: CGFloat = 26
    static let deviceWidth: CGFloat = 780
    static let deviceHeight: CGFloat = deviceWidth * 520 / 1280
    static let inspector: CGFloat = 186
    static let statusBar: CGFloat = 38
    static let sidebar: CGFloat = 160
    static var detailWidth: CGFloat { deviceWidth + 2 * pad + 1 }
    static var detailHeight: CGFloat { statusBar + 1 + 2 * pad + header + deviceHeight + inspector + 2 * gap }
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
            HStack(alignment: .top, spacing: 22) {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    row("Mode") {
                        Picker("", selection: $region.mode) {
                            ForEach(SwayLayout.modes.indices, id: \.self) { Text(SwayLayout.modes[$0]).tag($0) }
                        }
                        .labelsHidden().pickerStyle(.segmented).frame(width: 240)
                    }
                    if region.mode == 1 {
                        row("Notes") {
                            TextField("e.g. C3 E3 G3", text: $notesText)
                                .textFieldStyle(.roundedBorder).frame(width: 240)
                                .onSubmit(commitNotes)
                                .help(notesError ?? "Note names such as C3 or F#4, or numbers 0–127; press Return")
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.red, lineWidth: notesError == nil ? 0 : 1.5))
                        }
                        row("Note channel") {
                            NumberField(value: Binding(get: { (region.noteChannels.first ?? 0) + 1 },
                                                       set: { v in region.noteChannels = region.notes.map { _ in (v ?? 1) - 1 } }), range: 1...16)
                        }
                    }
                    row("Strike threshold") {
                        TextField("off", value: Binding(get: { region.strikeThreshold.map(Double.init) },
                                                        set: { region.strikeThreshold = $0.map { Float(min(1, max(0, $0))) } }),
                                  format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 58)
                    }
                    row("Colours") {
                        HStack {
                            colour($region.colorStart)
                            Image(systemName: "arrow.right").foregroundStyle(.secondary)
                            colour($region.colorEnd)
                        }
                    }
                }
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    row(region.mode == 2 ? "Trigger CC" : "X CC") { NumberField(value: $region.ccX, optional: true) }
                    row("Y CC") { NumberField(value: $region.ccY, optional: true) }
                    row("Sway CC") { NumberField(value: $region.swayCc, optional: true) }
                    row("Pulse CC") { NumberField(value: $region.pulseCc, optional: true) }
                    row("Press CC") { NumberField(value: $region.pressCc, optional: true) }
                }
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    row("LEDs") {
                        HStack(spacing: 4) {
                            NumberField(value: $region.ledStart.optional, range: 0...SwayLayout.ledCount)
                            Text("to").foregroundStyle(.secondary)
                            NumberField(value: $region.ledEnd.optional, range: 0...SwayLayout.ledCount)
                        }
                    }
                    row("Invert X") { Toggle("", isOn: $region.invertX).labelsHidden().help("Invert the horizontal axis and its LED animation") }
                    row("Clear on release") { Toggle("", isOn: $region.clearModulationOnRelease).labelsHidden().help("Reset the CC to 0 when the hand leaves") }
                }
                Spacer(minLength: 0)
            }
            .padding(4)
        }
        .onAppear { notesText = region.notes.map(noteName).joined(separator: " ") }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).lineLimit(1).fixedSize().gridColumnAlignment(.trailing)
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
