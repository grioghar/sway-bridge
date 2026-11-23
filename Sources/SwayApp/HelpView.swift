// Sway Bridge Help: how to use this app, and the essentials of operating the Sway itself.
// Hardware facts come from Audima's user manual and their staff's Discord posts
// (see docs/sway-reference.md); things this project measured itself are marked as such.
import SwiftUI

private struct HelpTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let sections: [HelpSection]
}

private struct HelpSection: Hashable {
    let heading: String
    let points: [String]
}

private let helpTopics: [HelpTopic] = [
    HelpTopic(id: "start", title: "Getting Started", symbol: "play.circle", sections: [
        HelpSection(heading: "Connect", points: [
            "Plug the Sway's right-hand USB-C port into this Mac and switch it on: hold the knob beside the Sway's display for 2 seconds.",
            "Quit Audima's own app (The Sway) first. Both apps need the same connection and only one can have it.",
            "The dot at the top of the window turns green and shows the firmware version when Sway Bridge has found the Sway. The first read of all 36 presets takes a few seconds.",
        ]),
        HelpSection(heading: "The window", points: [
            "Left: one bank of six presets at a time; the 1–6 strip picks the bank. The green dot marks the preset that is active on the Sway.",
            "The grid button (also All Presets in the toolbar) shows all 36 presets at once; click one to edit it.",
            "Centre: a drawing of the Sway. The coloured boxes above it are the sensing regions of the preset, as seen from above.",
            "Below: the settings for whatever you clicked on the drawing.",
        ]),
        HelpSection(heading: "Before you unplug", points: [
            "Switch the Sway off with its display knob (hold 2 seconds) before pulling the cable. Audima warns that unplugging while it is on can corrupt presets.",
            "Sway Bridge keeps a copy of the Sway's presets every time they change, in Library/Application Support/Sway Bridge/backups in your home folder.",
        ]),
    ]),
    HelpTopic(id: "edit", title: "Editing a Preset", symbol: "slider.horizontal.3", sections: [
        HelpSection(heading: "Pick what to edit", points: [
            "Click a preset in the sidebar, or one of the six numbered buttons on the drawn display, to edit it. Editing a preset does not change which one the Sway is playing.",
            "Click a region, a pad or a dial on the drawing. Its settings appear underneath.",
        ]),
        HelpSection(heading: "Regions", points: [
            "Mode: Instrument plays notes when a hand enters; Modulation sends controller (CC) values as the hand moves; Trigger sends one CC on entry and a continuous one for height.",
            "Notes: type names such as C3 E3 G3, or numbers 0–127, then press Return. Up to 15.",
            "X CC and Y CC are the controllers for left–right and up–down, each with its own MIDI channel (the “ch” box). Leave a CC box empty to switch that output off.",
            "MPE (Glide) puts each note on its own channel so sliding between regions bends pitch; the instrument you play must have MPE switched on too.",
            "Retrigger motion is a setting stored by the Sway whose effect has not been tested here. It is off in every factory preset.",
            "Sway, Pulse and Press CC are the extra gestures: shaking side to side, lifting after a note, and pushing down.",
            "Colours set the LED gradient for the region; LEDs sets which part of the light bar it uses.",
            "Key − and + at the top move every note of the preset, region notes and pad notes together, a semitone at a time. Use it to put a preset into another key without retyping notes. Nothing changes on the Sway until you Send.",
            "Changing how the field is divided into regions (the layout) is not supported yet. Use Audima's app for that.",
        ]),
        HelpSection(heading: "Pads and dials", points: [
            "Pads are numbered across the top row first, left to right, then the bottom row.",
            "Each dial has eight pages, A to H, each with its own CC number and MIDI channel. The Dial page control chooses which page the drawing shows.",
            "The Sway only uses these pad and dial settings in its custom mapping mode. See “On the Sway Itself”.",
        ]),
        HelpSection(heading: "Send, revert, reload", points: [
            "Send to Sway (⌘S) stores the preset on the Sway, reads it back and checks it arrived intact. The Sway switches to that preset.",
            "Revert throws away your unsent changes. Reload reads everything from the Sway again.",
            "“Unsent changes” in the toolbar means the editor differs from what is on the Sway.",
        ]),
    ]),
    HelpTopic(id: "switch", title: "Switching Presets", symbol: "arrow.left.arrow.right", sections: [
        HelpSection(heading: "From this app", points: [
            "Select a preset and click Switch Sway (⌘↩), or right-click a preset in the sidebar or the All Presets grid.",
            "Sway Bridge sends the Sway a MIDI Program Change and then asks it which preset is active, so an error here means the Sway really did not switch. This needs Sway firmware 1.3.0 or later.",
            "Firmware 1.3.0 has a flaw: whenever a preset is entered other than by sending it from the computer (Program Change, or the Sway's own preset buttons), the Sway overwrites every region's chord type with the first region's. While Sway Bridge is running it checks each preset the Sway moves to and, if it finds exactly that damage, puts the preset back as it was; the Sway reloads the preset for a moment when this happens. With Sway Bridge closed nothing protects the preset; sending it again from here repairs it.",
        ]),
        HelpSection(heading: "From Ableton Live or another DAW", points: [
            "Send a Program Change to the Sway's MIDI port. Measured on firmware 1.3.0: values 0–35 select the presets in order, bank 1 preset 1 first (in software that counts from 1, use 1–36).",
            "The next two values are Sleep and Wake: 36 and 37 (37 and 38 when counting from 1). Measured: after Sleep the sensors send nothing until Wake arrives, and the preset stays where it was.",
        ]),
        HelpSection(heading: "On the Sway", points: [
            "Press one of the six round buttons at the display to load that preset of the current bank.",
            "To change bank, hold the preset button with the bank's number for about 2 seconds: holding button 3 goes to bank 3 and lands on its first preset. Then press a button briefly to choose the preset. (Checked on firmware 1.3.0. Audima's manual describes a separate bank selection screen, which this firmware does not show.)",
            "This window follows the Sway: when you change preset on the hardware, the editor moves to it unless you have unsent changes.",
        ]),
    ]),
    HelpTopic(id: "live", title: "Live View and OBS", symbol: "dot.radiowaves.left.and.right", sections: [
        HelpSection(heading: "In this window", points: [
            "While you are viewing the preset that is active on the Sway, the drawing lights up as you play: pads and buttons glow, dials show their value, and each region shows a line at your hand's height with a bead for its left–right position.",
            "If you are viewing a different preset, live display is off, because the incoming MIDI would be matched against the wrong settings.",
            "The dial page follows whichever page you are using on the hardware.",
        ]),
        HelpSection(heading: "OBS overlay", points: [
            "While Sway Bridge is running it serves an overlay for streaming. In OBS add a Browser source and paste the address from the menu bar icon: Copy OBS Overlay URL.",
            "The outline style draws only outlines so your video shows through. Add &field=levels for thin hand-level lines, &field=full for filled regions, or &field=0 for no field at all.",
            "OBS Overlay Options, in the menu bar icon and the Help menu, chooses the look: Solid, Outline, or Bold outline with thick lines and heavier text for small or busy pictures. It can also put a colour behind the drawing that fades out at the edges. Copy OBS Overlay URL then gives the address for what you chose.",
            "Add &demo=1 to see a fake performance while you position the source.",
            "Closing this window does not stop the overlay. Quit from the menu bar icon to stop it.",
        ]),
    ]),
    HelpTopic(id: "hardware", title: "On the Sway Itself", symbol: "pianokeys", sections: [
        HelpSection(heading: "Display knob", points: [
            "Hold 2 seconds to switch on or off.",
            "The screen shows SLEEP, the region number and the bank and preset (for example B1 P2) on its top line, and under that the outputs of the region with their CC numbers (for example X1 50, Y1 38). One item is underlined.",
            "The knob moves between those items and can select one. Be careful with it: with an output selected, turning the knob changes that output's CC number and the Sway saves the change into the preset. If a controller number has changed by itself, this is why; Reload here shows what the Sway now holds.",
            "While one output is selected the Sway sends only that output. This is how you teach a DAW one output at a time, and it is also the usual reason “only one axis works”. On the test unit the Sway kept sending a single axis and the knob action that returns it to sending everything was not worked out.",
            "SLEEP pauses every sensor so you can reach across the Sway. It is one of the items on the screen.",
        ]),
        HelpSection(heading: "Pads, dials and buttons", points: [
            "Pads normally glow pink and send fixed notes (0–15 on MIDI channel 1). Press the bottom-left black button of the right-hand group to switch to the custom mapping stored in the preset; the pads turn green. Press it again to go back. If your pad or dial edits seem to do nothing, this is almost always why.",
            "Clicking a dial changes the dial page: click dial 2 and all eight dials send on page B, dial 3 for page C, and so on; click dial 1 to return to page A. That gives 64 controls from eight dials. (Audima's manual also describes a dial press as sending its own CC.)",
            "Seven of the eight black buttons send a note on MIDI channel 2, whatever the preset: left group 0 and 1 on top, 4 and 5 below; right group 2 and 3 on top, 7 at bottom right. Map them in your DAW with MIDI learn. The eighth, bottom left of the right group, is the pink/green pad switch and sends nothing.",
            "The pads take a firm press. Their contacts are at the outer edge, so pressing near an edge works better than the middle.",
        ]),
        HelpSection(heading: "Power", points: [
            "If the Sway starts and then shuts off, or switches off while you play, the port is not giving it enough power (common on M1 MacBooks). Connect the second cable from the middle USB-C port to a wall adapter, plug power in first, then the Mac, then switch on.",
            "On firmware 1.3.0 the status line here shows “low-power mode” when the Sway is running on reduced power. Everything works; the lights are dimmer.",
            "The sensors need a few seconds after power-up. If regions jump or trigger on their own, wait five seconds before switching on, and keep direct sunlight off the sensor strip.",
        ]),
        HelpSection(heading: "No calibration, no reset", points: [
            "The Sway has no calibration procedure. To return to factory presets, load Audima's base project with their app.",
        ]),
    ]),
    HelpTopic(id: "trouble", title: "Troubleshooting", symbol: "wrench.and.screwdriver", sections: [
        HelpSection(heading: "“Sway not connected”", points: [
            "Check the Sway is switched on and plugged into its right-hand port, directly rather than through a hub.",
            "Quit Audima's app, and any second copy of Sway Bridge or the sway-bridge command-line tool.",
            "If the banner says the Sway was found but is not answering, switch it off and on with its display knob.",
        ]),
        HelpSection(heading: "“no MIDI” in the status line", points: [
            "Presets can still be read and edited, but live display and preset switching need the Sway's MIDI port. Open Audio MIDI Setup and check that “Audima Labs The Sway” appears.",
        ]),
        HelpSection(heading: "A preset did not send", points: [
            "Nothing was lost: your edits stay in the editor. Check the connection and press Send again.",
            "If the Sway stops responding altogether after a failed send, switch it off and on.",
        ]),
        HelpSection(heading: "The overlay is unavailable", points: [
            "Another program is using port 7729, usually a second copy of Sway Bridge. Quit it and reopen this app.",
        ]),
        HelpSection(heading: "About", points: [
            "Sway Bridge is an independent project and is not made or endorsed by Audima Labs. It was built against firmware 1.3.0; other versions may behave differently.",
            "Every byte of a preset is now accounted for. The black buttons and dial clicks are not preset settings at all: seven buttons always send fixed notes on MIDI channel 2, one switches the pad layout, and a dial click only changes dial page.",
        ]),
    ]),
]

struct HelpView: View {
    @State private var selected: String? = helpTopics[0].id

    var body: some View {
        NavigationSplitView {
            List(helpTopics, selection: $selected) { topic in
                Label(topic.title, systemImage: topic.symbol).tag(topic.id)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            if let topic = helpTopics.first(where: { $0.id == selected }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(topic.title).font(.largeTitle.bold())
                        ForEach(topic.sections, id: \.self) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.heading).font(.title3.bold())
                                ForEach(section.points, id: \.self) { point in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text("•").foregroundStyle(.secondary)
                                        Text(point).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(topic.id)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}
