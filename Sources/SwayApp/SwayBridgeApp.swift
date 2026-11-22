// Sway Bridge for macOS: a native configurator for the Audima Sway. The app also serves the
// OBS overlay on http://localhost:7729/overlay/ for as long as it is running.
import SwiftUI
import SwayKit

@main
struct SwayBridgeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Sway Bridge", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1240, height: 860)
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Send to Sway") { model.send() }
                    .keyboardShortcut("s")
                    .disabled(!model.isDirty || !model.state.connected || model.busy)
                Button("Revert Changes") { model.revert() }
                    .disabled(!model.isDirty)
                Divider()
                Button("Reload from Sway") { model.reload() }
                    .keyboardShortcut("r")
                    .disabled(!model.state.connected || model.busy)
            }
            CommandGroup(replacing: .help) {
                Button("Open OBS Overlay in Browser") { Overlay.open(Overlay.solid) }
            }
        }

        MenuBarExtra("Sway Bridge", systemImage: model.state.connected ? "dot.radiowaves.left.and.right" : "bolt.horizontal.circle") {
            MenuBarContent().environmentObject(model)
        }
    }
}

enum Overlay {
    static let solid = "http://localhost:\(AppModel.port)/overlay/"
    static let outline = "http://localhost:\(AppModel.port)/overlay/?style=outline"

    static func copy(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    static func open(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.statusText)
        if let slot = model.selection {
            Text("Active: bank \(slot.bank + 1), preset \(slot.preset + 1) · \(model.presetName(slot))")
        }
        Divider()
        Button("Open Configurator") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Copy OBS Overlay URL") { Overlay.copy(Overlay.solid) }
        Button("Copy OBS Overlay URL (Outline Style)") { Overlay.copy(Overlay.outline) }
        Button("Open OBS Overlay in Browser") { Overlay.open(Overlay.solid) }
        Divider()
        Button("Quit Sway Bridge") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
