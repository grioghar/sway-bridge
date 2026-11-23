// OBS overlay options: pick a style and an optional soft-edged background colour, and get the
// address to paste into an OBS Browser source. The choices are remembered between launches.
import SwiftUI

extension Overlay {
    static let bold = "http://localhost:\(AppModel.port)/overlay/?style=bold"

    /// The address for the options saved in the Overlay Options window.
    static var chosen: String {
        let d = UserDefaults.standard
        var items: [String] = []
        let style = d.string(forKey: "overlay.style") ?? "solid"
        if style != "solid" { items.append("style=\(style)") }
        let field = d.string(forKey: "overlay.field") ?? "auto"
        if field != "auto" { items.append("field=\(field)") }
        if d.bool(forKey: "overlay.backdrop") {
            let hex = (d.string(forKey: "overlay.backdropColor") ?? "#101830").dropFirst()
            let opacity = d.object(forKey: "overlay.backdropOpacity") as? Double ?? 0.8
            let alpha = String(format: "%02x", Int((min(1, max(0, opacity)) * 255).rounded()))
            items.append("backdrop=%23\(hex)\(alpha)")
            let fade = d.object(forKey: "overlay.fade") as? Double ?? 40
            if Int(fade) != 40 { items.append("fade=\(Int(fade))") }
        }
        return solid + (items.isEmpty ? "" : "?" + items.joined(separator: "&"))
    }
}

struct OverlayOptionsView: View {
    @AppStorage("overlay.style") private var style = "solid"
    @AppStorage("overlay.field") private var field = "auto"
    @AppStorage("overlay.backdrop") private var backdrop = false
    @AppStorage("overlay.backdropColor") private var colorHex = "#101830"
    @AppStorage("overlay.backdropOpacity") private var opacity = 0.8
    @AppStorage("overlay.fade") private var fade = 40.0
    @State private var copied = false

    var body: some View {
        // Reading the stored values here keeps the address below in step with the controls.
        let _ = (style, field, backdrop, colorHex, opacity, fade)
        Form {
            Picker("Style", selection: $style) {
                Text("Solid").tag("solid")
                Text("Outline").tag("outline")
                Text("Bold outline").tag("bold")
            }
            .pickerStyle(.segmented)
            Picker("Hands", selection: $field) {
                Text("Automatic").tag("auto")
                Text("Filled regions").tag("full")
                Text("Level lines").tag("levels")
                Text("Hidden").tag("0")
            }
            Toggle("Background colour that fades at the edges", isOn: $backdrop)
            if backdrop {
                ColorPicker("Colour", selection: Binding(get: { Color(hex: colorHex) }, set: { colorHex = $0.hex }), supportsOpacity: false)
                LabeledContent("Strength") {
                    Slider(value: $opacity, in: 0.1...1)
                    Text("\(Int(opacity * 100))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                LabeledContent("Edge fade") {
                    Slider(value: $fade, in: 0...120, step: 5)
                    Text("\(Int(fade))").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
            }
            Section("Address for the OBS Browser source (1280 × 520)") {
                Text(Overlay.chosen).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(copied ? "Copied" : "Copy Address") {
                        Overlay.copy(Overlay.chosen)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                    Button("Preview in Browser") { Overlay.open(Overlay.chosen + (Overlay.chosen.contains("?") ? "&" : "?") + "demo=1") }
                        .help("Opens the overlay with a fake performance so you can judge the look")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
