import XCTest
import Foundation
@testable import SwayKit

/// Captures from a real device live in captures/; skip when absent.
private func capture(_ name: String) throws -> [UInt8] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let file = root.appendingPathComponent("captures").appendingPathComponent(name)
    guard let data = try? Data(contentsOf: file) else { throw XCTSkip("captures/\(name) not present") }
    return [UInt8](data)
}

final class CodecTests: XCTestCase {
    func testDeviceProjectRoundTripsByteExactly() throws {
        let raw = try capture("project-device.bin")
        let project = try Project(bytes: raw)
        XCTAssertEqual(project.presets.count, 36)
        XCTAssertEqual(project.presets[1].name, "X & Y Tracking")
        XCTAssertEqual(project.encoded(), raw)
    }

    func testRoundTripsThroughJSON() throws {
        let raw = try capture("project-device.bin")
        let json = try JSONEncoder().encode(try Project(bytes: raw))
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: json).encoded(), raw)
    }

    func testProjectFileRoundTripsByteExactly() throws {
        let raw = try capture("new-project.swayproj")
        XCTAssertEqual(try Project(bytes: raw, file: true).encoded(file: true), raw)
    }

    func testSelectedPresetBlob() throws {
        let raw = try capture("preset-selected.bin")
        let preset = try Preset(bytes: raw)
        XCTAssertEqual(preset.name, "X & Y Tracking")
        XCTAssertEqual(preset.encoded(), raw)
    }

    func testEditsLandInTheRightBytes() throws {
        var project = try Project(bytes: try capture("project-device.bin"))
        XCTAssertEqual(project.presets[1].regions[0].mode, 0)
        XCTAssertEqual(project.presets[1].regions[0].ccX, 0x32)
        project.presets[1].regions[0].ccX = 20
        project.presets[1].regions[0].invertX = true
        project.presets[1].regions[0].colorStart = "#00ff80"
        project.presets[1].name = "Renamed"
        let again = try Project(bytes: project.encoded()).presets[1]
        XCTAssertEqual(again.regions[0].ccX, 20)
        XCTAssertTrue(again.regions[0].invertX)
        XCTAssertEqual(again.regions[0].colorStart, "#00ff80")
        XCTAssertEqual(again.name, "Renamed")
    }

    func testTruncatedDataThrowsInsteadOfCrashing() throws {
        let raw = try capture("project-device.bin")
        XCTAssertThrowsError(try Project(bytes: Array(raw.prefix(500))))
        XCTAssertThrowsError(try Project(bytes: [1, 2, 3]))
        XCTAssertThrowsError(try Preset(bytes: Array(raw[2..<60])))
    }
}

/// A fake Sway that stores one preset and, like the real one, goes silent if
/// fragments arrive before a selection.
private final class FakeSway: SwayTransport {
    var stored: [UInt8]
    var log: [UInt8] = []
    private var parser = FrameParser()
    private var outbox: [UInt8] = []
    private var incoming: [UInt8]?
    private var selected = false
    var silent = false

    init(_ initial: [UInt8]) { stored = initial }

    func send(_ bytes: [UInt8]) throws {
        for f in parser.push(bytes) {
            log.append(f.command)
            if silent { continue }
            switch f.command {
            case Command.handshake:
                outbox += Frame.encode(Command.handshake, [UInt8](repeating: 0, count: 20) + [1, 3, 0, 1, 28, 0])
            case Command.sendPresetSelection: selected = true; outbox += Frame.encode(Command.ack)
            case Command.requestPresetSelection: outbox += Frame.encode(Command.replySelection, [0, 1])
            case Command.requestPresetHeader:
                outbox += Frame.encode(Command.requestPresetHeader, [UInt8(stored.count & 0xff), UInt8(stored.count >> 8), 0, 0])
            case Command.requestPresetFragment:
                let i = Int(f.payload[0]) | Int(f.payload[1]) << 8
                outbox += Frame.encode(Command.requestPresetFragment, Array(stored[(i * 56)..<min(stored.count, i * 56 + 56)]))
            case Command.sendPresetFragment:
                guard selected else { silent = true; continue }
                let size = Int(f.payload[0]) | Int(f.payload[1]) << 8
                let index = Int(f.payload[4]) | Int(f.payload[5]) << 8
                if incoming == nil { incoming = [] }
                XCTAssertEqual(incoming!.count, index * 50)
                incoming! += f.payload[6...]
                if incoming!.count >= size { stored = incoming!; incoming = nil; selected = false }
                outbox += Frame.encode(Command.ack)
            default: outbox += Frame.encode(Command.error)
            }
        }
    }

    func receive(timeout: Double) throws -> [UInt8] {
        // Deliver in small pieces to exercise reassembly.
        let n = min(outbox.count, 7)
        defer { outbox.removeFirst(n) }
        return Array(outbox.prefix(n))
    }
}

final class ProtocolTests: XCTestCase {
    func testFramesMatchBytesSeenOnTheWire() {
        XCTAssertEqual(Frame.encode(Command.handshake), [0x53, 0x57, 0x41, 0x59, 0x03, 0x00, 0x00, 0x03])
        XCTAssertEqual(Frame.encode(Command.requestPresetFragment, [1, 0]),
                       [0x53, 0x57, 0x41, 0x59, 0x22, 0x02, 0x00, 0x01, 0x00, 0x21])
    }

    func testParserResyncsAndHandlesSplitChunks() {
        var parser = FrameParser()
        let f = Frame.encode(0x23, [0, 1])
        XCTAssertEqual(parser.push([0xaa, 0x53] + f.prefix(5)), [])
        XCTAssertEqual(parser.push(Array(f.dropFirst(5))), [Frame(command: 0x23, payload: [0, 1], checksumOK: true)])
    }

    func testHandshakeFields() throws {
        let info = try SwayClient(transport: FakeSway([]), timeout: 0.3).handshake()
        XCTAssertEqual(info, DeviceInfo(name: "", firmware: "1.3.0", lowPower: true, brightness: 28, eepromCorrupted: false))
    }

    func testReadAndWritePreset() throws {
        let original = (0..<310).map { UInt8($0 & 0xff) }
        let device = FakeSway(original)
        let client = SwayClient(transport: device, timeout: 0.3)
        XCTAssertEqual(try client.selection(), PresetSelection(bank: 0, preset: 1))
        XCTAssertEqual(try client.readSelectedPreset(), original)
        let edited = original.map { $0 ^ 0x5a }
        try client.writePreset(bank: 0, preset: 1, bytes: edited)
        XCTAssertEqual(device.log.filter { $0 == Command.sendPresetFragment }.count, 7)
        XCTAssertLessThan(device.log.firstIndex(of: Command.sendPresetSelection)!, device.log.firstIndex(of: Command.sendPresetFragment)!)
        XCTAssertEqual(device.stored, edited)
    }

    func testSilentDeviceTimesOut() {
        let device = FakeSway([])
        device.silent = true
        XCTAssertThrowsError(try SwayClient(transport: device, timeout: 0.2).handshake()) {
            XCTAssertEqual($0 as? SwayError, .noAnswer(command: Command.handshake))
        }
    }
}

final class UtilityTests: XCTestCase {
    func testSHA1KnownVectors() {
        func hex(_ s: String) -> String { sha1(Array(s.utf8)).map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(hex("abc"), "a9993e364706816aba3e25717850c26c9cd0d89d")
        XCTAssertEqual(hex(""), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
        // RFC 6455 example key + GUID
        XCTAssertEqual(Data(sha1(Array("dGhlIHNhbXBsZSBub25jZQ==258EAFA5-E914-47DA-95CA-C5AB0DC85B11".utf8))).base64EncodedString(),
                       "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    }

    func testMIDIStreamParser() {
        var p = MIDIStreamParser()
        XCTAssertEqual(p.push([0x90, 73, 90, 73]), [[0x90, 73, 90]])           // second note pending
        XCTAssertEqual(p.push([0xf8, 0]), [[0x90, 73, 0]])                      // running status, real-time ignored
        XCTAssertEqual(p.push([0xb3, 20, 30, 0xc0, 5]), [[0xb3, 20, 30], [0xc0, 5]])
        XCTAssertEqual(p.push([0xf0, 1, 2, 3, 0xf7, 4, 0x80, 1, 2]), [[0x80, 1, 2]]) // SysEx skipped
    }
}
