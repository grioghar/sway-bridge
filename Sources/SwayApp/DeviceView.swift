// A drawing of the Sway itself: the sensing field above it, the LED strip, dials, pads,
// small buttons and the centre display, laid out as on the hardware. Every control is
// clickable for editing and lights up with live MIDI from the device.
import SwiftUI
import SwayKit

/// Layout in a 1280 x 520 space (the same one the OBS overlay uses).
private enum Geo {
    static let size = CGSize(width: 1280, height: 520)
    static let field = CGRect(x: 60, y: 16, width: 1160, height: 190)
    static let body = CGRect(x: 20, y: 228, width: 1240, height: 280)
    static let strip = CGRect(x: 60, y: 246, width: 1160, height: 10)
    static let display = CGRect(x: 500, y: 330, width: 280, height: 150)
    static let pad: CGFloat = 58, gap: CGFloat = 12

    static func origin(left: Bool) -> CGFloat { left ? 76 : 1280 - 76 - (4 * pad + 3 * gap) }

    /// Dial centres, left cluster then right.
    static let dials: [CGPoint] = [true, false].flatMap { left in
        (0..<4).map { CGPoint(x: origin(left: left) + pad / 2 + CGFloat($0) * (pad + gap), y: 318) }
    }
    /// Pad frames in preset order. Audima's own pad panel numbers them across the whole top
    /// row first (left four, then right four), then across the bottom row.
    static let pads: [CGRect] = (0..<16).map { i in
        let row = i / 8, col = i % 8
        return CGRect(x: origin(left: col < 4) + CGFloat(col % 4) * (pad + gap), y: 356 + CGFloat(row) * (pad + gap), width: pad, height: pad)
    }
    /// Small buttons: per side, a 2 x 2 block of narrow upright keys right beside the pads,
    /// lined up with the two pad rows (from Audima's product renders).
    static let buttons: [CGRect] = [true, false].flatMap { left -> [CGRect] in
        let x0 = left ? origin(left: true) + 4 * (pad + gap) : origin(left: false) - gap - 2 * 26 - 8
        return (0..<2).flatMap { row in
            (0..<2).map { col in CGRect(x: x0 + CGFloat(col) * 34, y: 356 + CGFloat(row) * (pad + gap), width: 26, height: pad) }
        }
    }
}

struct DeviceView: View {
    let preset: Preset
    let open: Slot?
    let active: Slot?
    @Binding var selected: Control
    @Binding var dialPage: Int
    @ObservedObject var feed: LiveFeed
    var choosePreset: (Int) -> Void

    private var regions: [Region] { Array(preset.regions.prefix(preset.regionCount)) }
    private let accent = Color(red: 0.77, green: 0.3, blue: 1)

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / Geo.size.width
            ZStack(alignment: .topLeading) {
                chassis(scale: s)
                field(scale: s)
                ForEach(Geo.dials.indices, id: \.self) { dial(at: $0, scale: s) }
                ForEach(Geo.pads.indices, id: \.self) { pad(at: $0, scale: s) }
                ForEach(Geo.buttons.indices, id: \.self) { button(at: $0, scale: s) }
                display(scale: s)
            }
        }
        .aspectRatio(Geo.size.width / Geo.size.height, contentMode: .fit)
        .onChange(of: feed.dialPage) { page in if let page { dialPage = page } }   // follow the page in use on the hardware
    }

    private func place<V: View>(_ view: V, _ r: CGRect, _ s: CGFloat) -> some View {
        view.frame(width: r.width * s, height: r.height * s).position(x: r.midX * s, y: r.midY * s)
    }

    // MARK: body, LED strip and sensor windows

    private func chassis(scale s: CGFloat) -> some View {
        Canvas { context, _ in
            func rect(_ r: CGRect) -> CGRect { CGRect(x: r.minX * s, y: r.minY * s, width: r.width * s, height: r.height * s) }
            context.fill(Path(roundedRect: rect(Geo.field), cornerRadius: 12 * s), with: .color(Color(white: 0.05)))
            context.fill(Path(roundedRect: rect(Geo.body), cornerRadius: 22 * s), with: .color(Color(white: 0.12)))
            // LED strip: each region owns a run of LEDs, which brighten while the region is played.
            var colours = [Color?](repeating: nil, count: SwayLayout.ledCount)
            for (index, r) in regions.enumerated() where r.ledStart < r.ledEnd {
                let lit = feed.isHot("region-\(index)") || feed.hands[index] != nil
                for led in max(0, r.ledStart)..<min(r.ledEnd, SwayLayout.ledCount) { colours[led] = Color(hex: r.colorStart).opacity(lit ? 1 : 0.4) }
            }
            let step = Geo.strip.width / CGFloat(SwayLayout.ledCount)
            for led in 0..<SwayLayout.ledCount {
                let r = CGRect(x: Geo.strip.minX + CGFloat(led) * step + 0.75, y: Geo.strip.minY, width: step - 1.5, height: Geo.strip.height)
                context.fill(Path(roundedRect: rect(r), cornerRadius: 2 * s), with: .color(colours[led] ?? Color(white: 0.2)))
            }
            for sensor in 0..<16 {
                let r = CGRect(x: Geo.strip.minX + 26 + CGFloat(sensor) * ((Geo.strip.width - 76) / 15), y: 272, width: 24, height: 9)
                context.fill(Path(roundedRect: rect(r), cornerRadius: 4.5 * s), with: .color(Color(white: 0.22)))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: sensing field

    private func field(scale s: CGFloat) -> some View {
        ForEach(Array(regions.enumerated()), id: \.offset) { index, r in
            let frame = CGRect(
                x: Geo.field.minX + CGFloat(r.xMin / SwayLayout.sensorWidth) * Geo.field.width + 2,
                y: Geo.field.minY + CGFloat(1 - r.yMax / SwayLayout.sensorDepth) * Geo.field.height + 2,
                width: max(8, CGFloat((r.xMax - r.xMin) / SwayLayout.sensorWidth) * Geo.field.width - 4),
                height: max(8, CGFloat((r.yMax - r.yMin) / SwayLayout.sensorDepth) * Geo.field.height - 4))
            place(RegionBox(region: r, index: index, isSelected: selected == .region(index),
                            isHot: feed.isHot("region-\(index)"), hand: feed.hands[index])
                    .onTapGesture { selected = .region(index) }, frame, s)
        }
    }

    // MARK: controls

    private func dial(at index: Int, scale s: CGFloat) -> some View {
        let centre = Geo.dials[index], value = feed.dials[index]
        let isSelected = selected == .dial(index), hot = feed.isHot("dial-\(dialPage)-\(index)")
        let number = dialPage < preset.encoders.ccNumbers.count && index < preset.encoders.ccNumbers[dialPage].count
            ? preset.encoders.ccNumbers[dialPage][index] : nil
        let knob = ZStack {
            Circle().fill(Color(white: hot ? 0.34 : 0.22))
            Circle().strokeBorder(isSelected ? Color.white : Color(white: 0.34), lineWidth: (isSelected ? 2.5 : 1) * s)
            if let value {
                Circle().trim(from: 0, to: 0.75 * CGFloat(value) / 127)
                    .stroke(accent, style: StrokeStyle(lineWidth: 3.5 * s, lineCap: .round))
                    .rotationEffect(.degrees(135)).padding(-4.5 * s)
            }
            Capsule().fill(Color(white: 0.92)).frame(width: 2.5 * s, height: 9 * s).offset(y: -8.5 * s)
                .rotationEffect(.degrees(-135 + 270 * Double(value ?? 0) / 127))
        }
        .contentShape(Circle())
        .onTapGesture { selected = .dial(index) }
        .help("Dial \(index + 1)")
        return ZStack {
            place(knob, CGRect(x: centre.x - 17, y: centre.y - 17, width: 34, height: 34), s)
            place(Text(value.map { "\($0)" } ?? number.map { "CC \($0)" } ?? "")
                    .font(.system(size: 9.5 * s, weight: .medium)).foregroundStyle(hot ? Color.white : Color(white: 0.62))
                    .allowsHitTesting(false),
                  CGRect(x: centre.x - 30, y: centre.y - 37, width: 60, height: 12), s)
        }
    }

    private func pad(at index: Int, scale s: CGFloat) -> some View {
        let hot = feed.isHot("pad-\(index)"), isSelected = selected == .pad(index)
        let complete = index < preset.pads.rootNotes.count && index < preset.pads.rootOctaves.count
        let label = complete ? noteName(preset.pads.rootOctaves[index] * 12 + preset.pads.rootNotes[index]) : ""
        return place(ZStack {
            RoundedRectangle(cornerRadius: 9 * s).fill(hot ? accent : Color(white: 0.22))
            RoundedRectangle(cornerRadius: 9 * s).strokeBorder(isSelected ? Color.white : Color(white: 0.34), lineWidth: (isSelected ? 2.5 : 1) * s)
            Text(label).font(.system(size: 13 * s, weight: .semibold)).foregroundStyle(.white.opacity(hot ? 1 : 0.7))
        }
        .contentShape(Rectangle())
        .onTapGesture { selected = .pad(index) }
        .help(padName(index)), Geo.pads[index], s)
    }

    private func button(at index: Int, scale s: CGFloat) -> some View {
        let hot = feed.isHot("button-\(index)"), isSelected = selected == .button(index)
        return place(ZStack {
            RoundedRectangle(cornerRadius: 5 * s).fill(hot ? Color.white : Color(white: 0.22))
            RoundedRectangle(cornerRadius: 5 * s).strokeBorder(isSelected ? Color.white : Color(white: 0.34), lineWidth: (isSelected ? 2.5 : 1) * s)
        }
        .contentShape(Rectangle())
        .onTapGesture { selected = .button(index) }
        .help("Small button \(index + 1)"), Geo.buttons[index], s)
    }

    // MARK: centre display

    private func display(scale s: CGFloat) -> some View {
        let d = Geo.display
        let scale = SwayLayout.scales.indices.contains(preset.scale) ? SwayLayout.scales[preset.scale] : "Scale \(preset.scale)"
        return ZStack(alignment: .topLeading) {
            place(RoundedRectangle(cornerRadius: 10 * s).fill(Color.black), d, s)
            // The six preset buttons: lit = active on the Sway, ringed = shown in the editor.
            ForEach(0..<SwayLayout.presetsPerBank, id: \.self) { i in
                let isActive = active?.bank == open?.bank && active?.preset == i
                let isOpen = open?.preset == i
                place(ZStack {
                    Circle().fill(isActive ? accent : Color(white: 0.22))
                    Circle().strokeBorder(isOpen ? Color.white : Color.clear, lineWidth: 2 * s)
                    Text("\(i + 1)").font(.system(size: 10 * s, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                }
                .contentShape(Circle())
                .onTapGesture { choosePreset(i) }
                .help("Edit preset \(i + 1) of this bank. On the Sway: press for the preset, hold about 2 seconds for bank \(i + 1)."),
                      CGRect(x: d.minX + 15 + CGFloat(i) * 38, y: d.minY + 13, width: 22, height: 22), s)
            }
            place(ZStack {
                Circle().fill(Color(white: 0.22))
                Text(open.map { "\($0.bank + 1)" } ?? "").font(.system(size: 13 * s, weight: .bold)).foregroundStyle(.white)
            }
            .help("Bank"), CGRect(x: d.maxX - 41, y: d.minY + 9, width: 30, height: 30), s)
            place(VStack(alignment: .leading, spacing: 4 * s) {
                Text(preset.name.isEmpty ? "(unnamed)" : preset.name).font(.system(size: 20 * s, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text("Bank \((open?.bank ?? 0) + 1) · Preset \((open?.preset ?? 0) + 1) · \(scale)").font(.system(size: 12 * s)).foregroundStyle(Color(white: 0.7))
                Text("Dial page \(pageName(dialPage))").font(.system(size: 12 * s)).foregroundStyle(Color(white: 0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false), CGRect(x: d.minX + 16, y: d.minY + 54, width: d.width - 32, height: 86), s)
        }
    }
}

// MARK: - inspector for whichever control is selected

struct ControlInspector: View {
    @EnvironmentObject var model: AppModel
    @Binding var draft: Preset
    @Binding var dialPage: Int

    var body: some View {
        switch model.selected {
        case .region:
            if let region = model.regionBinding {
                Inspector(region: region, index: model.region, count: draft.regionCount)
            } else {
                Text("This preset has no regions.").foregroundStyle(.secondary)
            }
        case .pad(let index):
            GroupBox(padName(index)) {
                if [draft.pads.rootNotes, draft.pads.rootOctaves, draft.pads.channels].allSatisfy({ index < $0.count }) {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 7) {
                        GridRow {
                            Text("Note").foregroundStyle(.secondary)
                            HStack {
                                NumberField(value: Binding(get: { draft.pads.rootOctaves[index] * 12 + draft.pads.rootNotes[index] }, set: { v in
                                    guard let v else { return }
                                    draft.pads.rootNotes[index] = v % 12; draft.pads.rootOctaves[index] = v / 12
                                }))
                                Text(noteName(draft.pads.rootOctaves[index] * 12 + draft.pads.rootNotes[index])).foregroundStyle(.secondary)
                            }
                        }
                        GridRow {
                            Text("MIDI channel").foregroundStyle(.secondary)
                            NumberField(value: Binding(get: { draft.pads.channels[index] + 1 }, set: { v in if let v { draft.pads.channels[index] = v - 1 } }), range: 1...16)
                        }
                    }
                    .padding(6)
                }
            }
            .frame(maxWidth: 420)
        case .dial(let index):
            GroupBox("Dial \(index + 1)") {
                Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow {
                        Text("Page").foregroundStyle(.secondary)
                        ForEach(draft.encoders.ccNumbers.indices, id: \.self) { page in
                            Text(pageName(page)).fontWeight(page == dialPage ? .bold : .regular)
                                .foregroundStyle(page == dialPage ? Color.accentColor : Color.secondary)
                        }
                    }
                    GridRow {
                        Text("CC").foregroundStyle(.secondary)
                        ForEach(draft.encoders.ccNumbers.indices, id: \.self) { page in
                            if index < draft.encoders.ccNumbers[page].count {
                                NumberField(value: Binding(get: { draft.encoders.ccNumbers[page][index] }, set: { v in if let v { draft.encoders.ccNumbers[page][index] = v } }),
                                            hot: model.feed.isHot("dial-\(page)-\(index)"))
                            }
                        }
                    }
                    GridRow {
                        Text("Channel").foregroundStyle(.secondary)
                        ForEach(draft.encoders.channels.indices, id: \.self) { page in
                            if index < draft.encoders.channels[page].count {
                                NumberField(value: Binding(get: { draft.encoders.channels[page][index] + 1 }, set: { v in if let v { draft.encoders.channels[page][index] = v - 1 } }), range: 1...16)
                            }
                        }
                    }
                }
                .padding(6)
            }
        case .button(let index):
            GroupBox("Small button \(index + 1)") {
                Text("The black buttons are not part of a preset, so there is nothing to edit: this one always sends note \(index) on MIDI channel 2, which you can map in your DAW. (Which physical button is which number has not been checked; press one and watch which lights up here.) On the right-hand group, holding the bottom-left button for 3 seconds switches the pads and dials to the custom mapping stored in the preset; the pads turn green.")
                    .foregroundStyle(.secondary).padding(6).frame(maxWidth: 420, alignment: .leading)
            }
        }
    }
}

/// "Pad 3 · top row, left" — pads are numbered across the top row, then the bottom row.
func padName(_ index: Int) -> String {
    "Pad \(index + 1) · \(index < 8 ? "top" : "bottom") row, \(index % 8 < 4 ? "left" : "right")"
}

/// Audima's app letters the eight dial pages A to H.
func pageName(_ page: Int) -> String {
    (0..<8).contains(page) ? String(UnicodeScalar(UInt8(65 + page))) : "\(page + 1)"
}
