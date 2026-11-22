// Log every MIDI message the Sway sends, with timestamps, for N seconds.
// usage: swift tools/midi-dump.swift [seconds] > capture.log
import CoreMIDI
import Foundation

let seconds = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 15 : 15
setvbuf(stdout, nil, _IOLBF, 0)

func name(_ o: MIDIObjectRef) -> String {
    var n: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(o, kMIDIPropertyDisplayName, &n)
    return n?.takeRetainedValue() as String? ?? "?"
}

var client = MIDIClientRef()
MIDIClientCreate("sway-dump" as CFString, nil, nil, &client)
var port = MIDIPortRef()
let t0 = Date()
MIDIInputPortCreateWithBlock(client, "in" as CFString, &port) { list, _ in
    var p = list.pointee.packet
    for _ in 0..<list.pointee.numPackets {
        let len = Int(p.length)
        let bytes = withUnsafeBytes(of: p.data) { Array($0.prefix(len)) }
        let t = String(format: "%8.3f", Date().timeIntervalSince(t0))
        print(t, bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
        p = MIDIPacketNext(&p).pointee
    }
}
var found = false
for i in 0..<MIDIGetNumberOfSources() {
    let s = MIDIGetSource(i)
    if name(s).lowercased().contains("sway") {
        MIDIPortConnectSource(port, s, nil)
        FileHandle.standardError.write("listening to \(name(s)) for \(seconds)s\n".data(using: .utf8)!)
        found = true
    }
}
if !found { FileHandle.standardError.write("Sway MIDI source not found\n".data(using: .utf8)!); exit(1) }
RunLoop.current.run(until: Date().addingTimeInterval(seconds))
