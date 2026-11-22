// Sway serial configuration protocol (firmware 1.3.0).
//
// Frame: 'SWAY' | cmd u8 | len u16 LE | payload | xor(cmd, len bytes, payload)
// The same command byte means different things in each direction; names here are
// host -> device and match what the official app logs.

public enum Command {
    public static let ack: UInt8 = 0x01
    public static let error: UInt8 = 0x02
    public static let handshake: UInt8 = 0x03
    public static let requestProjectHeader: UInt8 = 0x11    // -> 0x11 size u32
    public static let requestProjectFragment: UInt8 = 0x12  // index u16 -> 0x12 <=56 bytes
    public static let requestPresetHeader: UInt8 = 0x21     // -> 0x21 size u32 (selected preset)
    public static let requestPresetFragment: UInt8 = 0x22   // index u16 -> 0x22 <=56 bytes
    public static let sendPresetFragment: UInt8 = 0x23      // size u32, index u16, <=50 bytes -> ACK
    public static let sendPresetSelection: UInt8 = 0x24     // bank u8, preset u8 -> ACK. Sets the upload target; does not change the active preset
    public static let requestPresetSelection: UInt8 = 0x25  // -> 0x23 bank u8, preset u8 of the active preset
    public static let requestBrightness: UInt8 = 0x31       // -> 0x31 u8
    public static let sendBrightness: UInt8 = 0x32          // u8 -> ACK
    /// Device -> host reply to `requestPresetSelection`.
    public static let replySelection: UInt8 = 0x23
}

public struct Frame: Equatable {
    public var command: UInt8
    public var payload: [UInt8]
    public var checksumOK: Bool

    static let magic: [UInt8] = [0x53, 0x57, 0x41, 0x59] // "SWAY"

    public static func encode(_ command: UInt8, _ payload: [UInt8] = []) -> [UInt8] {
        let body = [command, UInt8(payload.count & 0xff), UInt8(payload.count >> 8)] + payload
        return magic + body + [body.reduce(0, ^)]
    }
}

/// Incremental parser: feed it bytes as they arrive, get complete frames back.
public struct FrameParser {
    private var buffer: [UInt8] = []
    public init() {}

    public mutating func push(_ bytes: [UInt8]) -> [Frame] {
        buffer += bytes
        var frames: [Frame] = []
        while true {
            // Resynchronise on the marker.
            while buffer.count >= 4 && Array(buffer[0..<4]) != Frame.magic { buffer.removeFirst() }
            guard buffer.count >= 8 else { break }
            let length = Int(buffer[5]) | Int(buffer[6]) << 8
            guard buffer.count >= length + 8 else { break }
            let checksum = buffer[4..<(7 + length)].reduce(0, ^)
            frames.append(Frame(command: buffer[4],
                                payload: Array(buffer[7..<(7 + length)]),
                                checksumOK: checksum == buffer[7 + length]))
            buffer.removeFirst(length + 8)
        }
        return frames
    }
}
