/// A byte pipe to the Sway. `receive` blocks for up to `timeout` seconds and returns
/// whatever arrived (possibly empty).
public protocol SwayTransport: AnyObject {
    func send(_ bytes: [UInt8]) throws
    func receive(timeout: Double) throws -> [UInt8]
}

public enum SwayError: Error, CustomStringConvertible, Equatable {
    case noAnswer(command: UInt8)
    case badChecksum
    case rejected(command: UInt8)
    case unexpectedReply(got: UInt8, to: UInt8)
    case malformed(String)

    public var description: String {
        func hex(_ b: UInt8) -> String { "0x" + String(b, radix: 16) }
        switch self {
        case .noAnswer(let c): return "Sway did not answer command \(hex(c))"
        case .badChecksum: return "bad checksum from Sway"
        case .rejected(let c): return "Sway rejected command \(hex(c))"
        case .unexpectedReply(let g, let t): return "unexpected reply \(hex(g)) to \(hex(t))"
        case .malformed(let m): return m
        }
    }
}

public struct DeviceInfo: Codable, Equatable {
    public var name: String
    public var firmware: String
    public var lowPower: Bool
    public var brightness: Int?
    public var eepromCorrupted: Bool
}

public struct PresetSelection: Codable, Equatable {
    public var bank: Int
    public var preset: Int
    public init(bank: Int, preset: Int) { self.bank = bank; self.preset = preset }
}

/// Synchronous request/response client. Not thread-safe: call it from one queue.
public final class SwayClient {
    public let transport: SwayTransport
    public var timeout: Double
    private var parser = FrameParser()
    private var pending: [Frame] = []

    static let readFragment = 56
    static let writeFragment = 50

    public init(transport: SwayTransport, timeout: Double = 1.5) {
        self.transport = transport
        self.timeout = timeout
    }

    @discardableResult
    private func request(_ command: UInt8, _ payload: [UInt8] = [], expect: UInt8) throws -> [UInt8] {
        pending.removeAll()
        try transport.send(Frame.encode(command, payload))
        let clock = ContinuousClock()
        let deadline = clock.now + .milliseconds(Int(timeout * 1000))
        while pending.isEmpty {
            guard clock.now < deadline else { throw SwayError.noAnswer(command: command) }
            pending += parser.push(try transport.receive(timeout: 0.1))
        }
        let frame = pending.removeFirst()
        guard frame.checksumOK else { throw SwayError.badChecksum }
        if frame.command == Command.error { throw SwayError.rejected(command: command) }
        guard frame.command == expect else { throw SwayError.unexpectedReply(got: frame.command, to: command) }
        return frame.payload
    }

    public func handshake() throws -> DeviceInfo {
        let p = try request(Command.handshake, expect: Command.handshake)
        guard p.count >= 23 else { throw SwayError.malformed("short handshake reply") }
        let name = String(decoding: p[0..<20].prefix { $0 != 0 }, as: UTF8.self)
        return DeviceInfo(name: name,
                          firmware: "\(p[20]).\(p[21]).\(p[22])",
                          lowPower: p.count > 23 && p[23] == 1,
                          brightness: p.count > 24 ? Int(p[24]) : nil,
                          eepromCorrupted: p.count > 25 && p[25] == 1)
    }

    public func selection() throws -> PresetSelection {
        let p = try request(Command.requestPresetSelection, expect: Command.replySelection)
        guard p.count == 2 else { throw SwayError.malformed("bad selection reply") }
        return PresetSelection(bank: Int(p[0]), preset: Int(p[1]))
    }

    public func select(bank: Int, preset: Int) throws {
        try request(Command.sendPresetSelection, [UInt8(bank), UInt8(preset)], expect: Command.ack)
    }

    public func brightness() throws -> Int {
        let p = try request(Command.requestBrightness, expect: Command.requestBrightness)
        guard let b = p.first else { throw SwayError.malformed("empty brightness reply") }
        return Int(b)
    }

    public func setBrightness(_ value: Int) throws {
        try request(Command.sendBrightness, [UInt8(clamping: value)], expect: Command.ack)
    }

    private func fetch(header: UInt8, fragment: UInt8) throws -> [UInt8] {
        let h = try request(header, expect: header)
        guard h.count == 4 else { throw SwayError.malformed("bad size header") }
        let size = Int(h[0]) | Int(h[1]) << 8 | Int(h[2]) << 16 | Int(h[3]) << 24
        var out: [UInt8] = []
        out.reserveCapacity(size)
        var index = 0
        while out.count < size {
            let part = try request(fragment, [UInt8(index & 0xff), UInt8(index >> 8)], expect: fragment)
            guard !part.isEmpty else { throw SwayError.malformed("empty fragment from Sway") }
            out += part
            index += 1
        }
        return Array(out.prefix(size))
    }

    public func readProject() throws -> [UInt8] {
        try fetch(header: Command.requestProjectHeader, fragment: Command.requestProjectFragment)
    }

    public func readSelectedPreset() throws -> [UInt8] {
        try fetch(header: Command.requestPresetHeader, fragment: Command.requestPresetFragment)
    }

    /// Upload one preset. The selection command MUST come first: sending fragments
    /// without it hangs the Sway's serial side until it is power-cycled.
    public func writePreset(bank: Int, preset: Int, bytes: [UInt8]) throws {
        try select(bank: bank, preset: preset)
        let n = bytes.count
        let size = [UInt8(n & 0xff), UInt8((n >> 8) & 0xff), UInt8((n >> 16) & 0xff), UInt8((n >> 24) & 0xff)]
        var index = 0
        while index * Self.writeFragment < n {
            let part = bytes[(index * Self.writeFragment)..<min(n, (index + 1) * Self.writeFragment)]
            try request(Command.sendPresetFragment, size + [UInt8(index & 0xff), UInt8(index >> 8)] + part, expect: Command.ack)
            index += 1
        }
    }
}
