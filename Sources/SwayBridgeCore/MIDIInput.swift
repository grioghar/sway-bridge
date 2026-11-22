// Listens to the Sway's MIDI output and hands each channel message to a callback.
//
// macOS: CoreMIDI is multi-client, so this runs alongside Ableton.
// Linux: reads the ALSA raw MIDI device node directly (no libasound needed).
// Windows: WinMM. The stock Windows USB MIDI driver is single-client, so if a DAW
//          already has the Sway open this will fail to open it (and vice versa).
import Foundation
import SwayKit

protocol MIDIListener: AnyObject {
    /// True while attached to the Sway.
    var isConnected: Bool { get }
    /// Attach if the Sway is present and we are not attached; detach if it has gone.
    func refresh()
}

typealias MIDIHandler = ([UInt8]) -> Void

func makeMIDIListener(matching name: String, handler: @escaping MIDIHandler) -> MIDIListener {
    #if canImport(CoreMIDI)
    return CoreMIDIListener(name: name, handler: handler)
    #elseif os(Linux)
    return ALSARawListener(name: name, handler: handler)
    #elseif os(Windows)
    return WinMMListener(name: name, handler: handler)
    #else
    return NoMIDIListener()
    #endif
}

final class NoMIDIListener: MIDIListener {
    var isConnected: Bool { false }
    func refresh() {}
}

#if canImport(CoreMIDI)
import CoreMIDI

final class CoreMIDIListener: MIDIListener {
    private let name: String
    private let handler: MIDIHandler
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var source: MIDIEndpointRef = 0
    private var parser = MIDIStreamParser()

    init(name: String, handler: @escaping MIDIHandler) {
        self.name = name.lowercased()
        self.handler = handler
        MIDIClientCreateWithBlock("sway-bridge" as CFString, &client) { _ in }
        MIDIInputPortCreateWithBlock(client, "in" as CFString, &port) { [weak self] list, _ in
            guard let self else { return }
            var packet = list.pointee.packet
            for _ in 0..<list.pointee.numPackets {
                let length = Int(packet.length)
                let bytes = withUnsafeBytes(of: packet.data) { Array($0.prefix(length)) }
                for message in self.parser.push(bytes) { self.handler(message) }
                packet = MIDIPacketNext(&packet).pointee
            }
        }
    }

    var isConnected: Bool { source != 0 }

    private func findSource() -> MIDIEndpointRef {
        for i in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(i)
            var value: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &value)
            if let n = value?.takeRetainedValue() as String?, n.lowercased().contains(name) { return endpoint }
        }
        return 0
    }

    func refresh() {
        let found = findSource()
        if found == source { return }
        if source != 0 { MIDIPortDisconnectSource(port, source) }
        source = found
        if found != 0 { MIDIPortConnectSource(port, found, nil) }
    }
}
#endif

#if os(Linux)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

final class ALSARawListener: MIDIListener {
    private let name: String
    private let handler: MIDIHandler
    private let lock = NSLock()
    private var running = false

    init(name: String, handler: @escaping MIDIHandler) {
        self.name = name.lowercased()
        self.handler = handler
    }

    var isConnected: Bool { lock.lock(); defer { lock.unlock() }; return running }

    /// Find the sound card whose description mentions the device, e.g. " 2 [Sway  ]: USB-Audio - The Sway".
    private func devicePath() -> String? {
        guard let cards = try? String(contentsOfFile: "/proc/asound/cards", encoding: .utf8) else { return nil }
        for line in cards.split(separator: "\n") where line.lowercased().contains(name) {
            if let number = line.split(separator: " ").first.flatMap({ Int($0) }) { return "/dev/snd/midiC\(number)D0" }
        }
        return nil
    }

    func refresh() {
        guard !isConnected, let path = devicePath() else { return }
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return }
        lock.lock(); running = true; lock.unlock()
        Thread.detachNewThread { [self] in
            var parser = MIDIStreamParser()
            var buffer = [UInt8](repeating: 0, count: 256)
            while true {
                let n = buffer.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
                if n <= 0 { break }                       // unplugged
                for message in parser.push(buffer.prefix(n)) { handler(message) }
            }
            close(fd)
            lock.lock(); running = false; lock.unlock()
        }
    }
}
#endif

#if os(Windows)
import WinSDK

/// WinMM delivers messages through a C callback, so the handler lives in a global.
private var winMMHandler: MIDIHandler?

private let winMMCallback: @convention(c) (HMIDIIN?, UINT, DWORD_PTR, DWORD_PTR, DWORD_PTR) -> Void = { _, message, _, param1, _ in
    guard message == UINT(MIM_DATA) else { return }
    let status = UInt8(param1 & 0xff)
    guard status >= 0x80, status < 0xf0 else { return }
    let d1 = UInt8((param1 >> 8) & 0xff), d2 = UInt8((param1 >> 16) & 0xff)
    let twoByte = (status & 0xf0) == 0xc0 || (status & 0xf0) == 0xd0
    winMMHandler?(twoByte ? [status, d1] : [status, d1, d2])
}

final class WinMMListener: MIDIListener {
    private let name: String
    private var handle: HMIDIIN?

    init(name: String, handler: @escaping MIDIHandler) {
        self.name = name.lowercased()
        winMMHandler = handler
    }

    var isConnected: Bool { handle != nil }

    private func deviceIndex() -> UINT? {
        for i in 0..<midiInGetNumDevs() {
            var caps = MIDIINCAPSW()
            guard midiInGetDevCapsW(UINT_PTR(i), &caps, UINT(MemoryLayout<MIDIINCAPSW>.size)) == MMRESULT(MMSYSERR_NOERROR) else { continue }
            let device = withUnsafeBytes(of: caps.szPname) { raw in
                String(decoding: raw.bindMemory(to: UInt16.self).prefix { $0 != 0 }, as: UTF16.self)
            }
            if device.lowercased().contains(name) { return i }
        }
        return nil
    }

    func refresh() {
        let index = deviceIndex()
        if handle != nil && index == nil {            // unplugged
            midiInStop(handle); midiInClose(handle); handle = nil
            return
        }
        guard handle == nil, let index else { return }
        var h: HMIDIIN?
        let callback = unsafeBitCast(winMMCallback, to: DWORD_PTR.self)
        guard midiInOpen(&h, index, callback, 0, DWORD(CALLBACK_FUNCTION)) == MMRESULT(MMSYSERR_NOERROR) else { return }
        midiInStart(h)
        handle = h
    }
}
#endif
