/// Splits a raw MIDI byte stream into complete channel messages, honouring running
/// status and skipping system real-time and SysEx. Used where the OS hands us raw bytes.
public struct MIDIStreamParser {
    private var status: UInt8 = 0
    private var data: [UInt8] = []
    private var inSysEx = false
    public init() {}

    private static func dataLength(_ status: UInt8) -> Int {
        switch status & 0xf0 {
        case 0xc0, 0xd0: return 1
        case 0x80, 0x90, 0xa0, 0xb0, 0xe0: return 2
        default: return 0
        }
    }

    public mutating func push<S: Sequence>(_ bytes: S) -> [[UInt8]] where S.Element == UInt8 {
        var out: [[UInt8]] = []
        for b in bytes {
            if b >= 0xf8 { continue }                       // real-time: ignore, keeps running status
            if b & 0x80 != 0 {
                inSysEx = b == 0xf0
                status = b < 0xf0 ? b : 0                   // system common cancels running status
                data.removeAll(keepingCapacity: true)
                continue
            }
            guard !inSysEx, status != 0 else { continue }
            data.append(b)
            if data.count == Self.dataLength(status) {
                out.append([status] + data)
                data.removeAll(keepingCapacity: true)
            }
        }
        return out
    }
}
