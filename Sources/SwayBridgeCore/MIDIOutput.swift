// Sends MIDI to the Sway (it listens for Program Change to switch presets and to sleep/wake).
//
// macOS only for now: CoreMIDI. On Linux and Windows `send` throws, and the callers report it.
import Foundation

protocol MIDISender: AnyObject {
    func send(_ bytes: [UInt8]) throws
}

func makeMIDISender(matching name: String) -> MIDISender {
    #if canImport(CoreMIDI)
    return CoreMIDISender(name: name)
    #else
    return NoMIDISender()
    #endif
}

final class NoMIDISender: MIDISender {
    func send(_ bytes: [UInt8]) throws {
        throw BridgeError(description: "sending MIDI to the Sway is not supported on this platform yet")
    }
}

#if canImport(CoreMIDI)
import CoreMIDI

final class CoreMIDISender: MIDISender {
    private let name: String
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()

    init(name: String) {
        self.name = name.lowercased()
        MIDIClientCreateWithBlock("sway-bridge-out" as CFString, &client) { _ in }
        MIDIOutputPortCreate(client, "out" as CFString, &port)
    }

    private func destination() -> MIDIEndpointRef? {
        for i in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(i)
            var value: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &value)
            if let n = value?.takeRetainedValue() as String?, n.lowercased().contains(name) { return endpoint }
        }
        return nil
    }

    func send(_ bytes: [UInt8]) throws {
        guard let endpoint = destination() else { throw BridgeError(description: "the Sway's MIDI input was not found") }
        guard !bytes.isEmpty, bytes.count <= 256 else { throw BridgeError(description: "bad MIDI message") }
        var list = MIDIPacketList()
        let packet = MIDIPacketListInit(&list)
        _ = MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, packet, 0, bytes.count, bytes)
        let status = MIDISend(port, endpoint, &list)
        guard status == noErr else { throw BridgeError(description: "MIDI send failed (\(status))") }
    }
}
#endif
