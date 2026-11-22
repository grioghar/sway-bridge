// Sway project <-> model codec.
//
// Layout (firmware 1.3.0, app 1.2.0), recovered from the device:
//   project  = ff 02 | preset * 36 | selectedBank u8 | selectedPreset u8
//   preset   = name[20] | scale u8 | layout u8 | regionCount u8 | region[79] * count | pads[80] | encoders[128]
// A .swayproj file is the same thing with every preset padded to 12 regions.
//
// Bytes whose meaning is not yet confirmed are carried through untouched in the
// `_raw` fields, so decode -> encode is always byte-exact.

public enum SwayLayout {
    public static let presetCount = 36
    public static let presetsPerBank = 6
    public static let regionSize = 79
    public static let fileRegions = 12
    public static let ledCount = 80
    /// Region coordinate space.
    public static let sensorWidth: Float = 41.43
    public static let sensorDepth: Float = 36.0
    public static let modes = ["Modulation", "Instrument", "Trigger"]   // Audima's names: M, I, X-Trigger
    public static let scales = ["Major", "Minor", "Dorian", "Phrygian", "Lydian", "Mixolydian", "Locrian", "Chromatic", "Custom"]
}

private let none: UInt8 = 0xff

public struct Region: Codable, Equatable {
    public var mode: Int                 // index into SwayLayout.modes
    public var xMin: Float, yMin: Float, xMax: Float, yMax: Float
    public var strikeThreshold: Float?   // nil = off
    public var ccX: Int?, ccX2: Int?     // X2 / Y2 are the second hand's CCs (used when Link Hands is off)
    public var ccY: Int?, ccY2: Int?
    public var swayCc: Int?
    public var pulseCc: Int?
    public var pressCc: Int?
    public var notes: [Int]              // up to 15
    public var rootNote: Int
    public var rootOctave: Int
    public var noteCount: Int
    public var noteChannels: [Int]
    public var chordInversion: Int       // 0 root, 1 first, 2 second; 0 in all factory presets
    public var chordType: Int
    public var colorStart: String        // "#rrggbb"
    public var colorEnd: String
    public var ledStart: Int
    public var ledEnd: Int
    public var clearModulationOnRelease: Bool
    public var invertX: Bool
    public var raw: [UInt8]?             // source of truth for bytes 45-48, 72, 77

    enum CodingKeys: String, CodingKey {
        case mode, xMin, yMin, xMax, yMax, strikeThreshold, ccX, ccX2, ccY, ccY2, swayCc, pulseCc, pressCc
        case notes, rootNote, rootOctave, noteCount, noteChannels, chordInversion, chordType
        case colorStart, colorEnd, ledStart, ledEnd, clearModulationOnRelease, invertX
        case raw = "_raw"
    }

    static var blank: [UInt8] {
        var b = [UInt8](repeating: 0, count: SwayLayout.regionSize)
        for i in 21..<42 { b[i] = none }
        for i in 49..<64 { b[i] = none }
        b[43] = 4
        b[78] = none
        writeFloat(-1, into: &b, at: 17)
        return b
    }

    init(bytes b: [UInt8]) {
        func cc(_ i: Int) -> Int? { b[i] == none ? nil : Int(b[i]) }
        mode = Int(b[0])
        xMin = readFloat(b, 1); yMin = readFloat(b, 5); xMax = readFloat(b, 9); yMax = readFloat(b, 13)
        let threshold = readFloat(b, 17)
        strikeThreshold = threshold < 0 ? nil : threshold
        ccX = cc(21); ccX2 = cc(22); ccY = cc(23); ccY2 = cc(24)
        swayCc = cc(25); pulseCc = cc(26); pressCc = cc(78)
        notes = b[27..<42].filter { $0 != none }.map(Int.init)
        rootNote = Int(b[42]); rootOctave = Int(b[43]); noteCount = Int(b[44])
        noteChannels = b[49..<64].prefix(min(Int(b[44]), 15)).map(Int.init)
        chordInversion = Int(b[64]); chordType = Int(b[65])
        colorStart = hexColor(b[66..<69]); colorEnd = hexColor(b[69..<72])
        ledStart = Int(b[73]); ledEnd = Int(b[74])
        clearModulationOnRelease = b[75] == 1
        invertX = b[76] == 1
        raw = b
    }

    func encoded() -> [UInt8] {
        var b = (raw?.count == SwayLayout.regionSize ? raw : nil) ?? Region.blank
        func cc(_ v: Int?) -> UInt8 { v.map { UInt8(clamping: $0) } ?? none }
        b[0] = UInt8(clamping: mode)
        writeFloat(xMin, into: &b, at: 1); writeFloat(yMin, into: &b, at: 5)
        writeFloat(xMax, into: &b, at: 9); writeFloat(yMax, into: &b, at: 13)
        writeFloat(strikeThreshold ?? -1, into: &b, at: 17)
        b[21] = cc(ccX); b[22] = cc(ccX2); b[23] = cc(ccY); b[24] = cc(ccY2)
        b[25] = cc(swayCc); b[26] = cc(pulseCc); b[78] = cc(pressCc)
        for i in 27..<42 { b[i] = none }
        for (i, n) in notes.prefix(15).enumerated() { b[27 + i] = UInt8(clamping: n) }
        b[42] = UInt8(clamping: rootNote); b[43] = UInt8(clamping: rootOctave); b[44] = UInt8(clamping: noteCount)
        for i in 49..<64 { b[i] = none }
        for (i, c) in noteChannels.prefix(15).enumerated() { b[49 + i] = UInt8(clamping: c) }
        b[64] = UInt8(clamping: chordInversion); b[65] = UInt8(clamping: chordType)
        b.replaceSubrange(66..<69, with: rgb(colorStart)); b.replaceSubrange(69..<72, with: rgb(colorEnd))
        b[73] = UInt8(clamping: ledStart); b[74] = UInt8(clamping: ledEnd)
        b[75] = clearModulationOnRelease ? 1 : 0
        b[76] = invertX ? 1 : 0
        return b
    }
}

public struct Pads: Codable, Equatable {
    public var rootNotes: [Int]
    public var chordTypes: [Int]       // field order matches the Pads struct in Audima's app
    public var rootOctaves: [Int]
    public var chordInversions: [Int]
    public var channels: [Int]
}

/// Dial settings. A page is selected on the hardware by clicking dial N (page N); every dial then
/// sends `ccNumbers[page][dial]` on `channels[page][dial]`. Nothing else is stored for a dial press,
/// and the eight black buttons are not in the preset at all (they send notes 0-7 on channel 2).
public struct Encoders: Codable, Equatable {
    public var ccNumbers: [[Int]]      // 8 pages x 8 dials
    public var channels: [[Int]]
}

public struct Preset: Codable, Equatable {
    public var name: String
    public var nameRaw: [UInt8]?
    public var scale: Int              // index into SwayLayout.scales
    public var layout: Int
    public var regionCount: Int
    public var regions: [Region]
    public var pads: Pads
    public var encoders: Encoders

    enum CodingKeys: String, CodingKey {
        case name, scale, layout, regionCount, regions, pads, encoders
        case nameRaw = "_nameRaw"
    }

    /// Size on the wire of a preset that stores `regions` regions.
    static func size(regions: Int) -> Int { 23 + regions * SwayLayout.regionSize + 208 }

    public init(bytes: [UInt8]) throws {
        guard bytes.count >= 23 else { throw SwayError.malformed("preset too short") }
        try self.init(bytes, at: 0, storedRegions: Int(bytes[22]))
    }

    init(_ b: [UInt8], at o: Int, storedRegions stored: Int) throws {
        guard stored <= SwayLayout.fileRegions, b.count >= o + Preset.size(regions: stored) else {
            throw SwayError.malformed("preset data is truncated")
        }
        nameRaw = Array(b[o..<(o + 20)])
        name = String(decoding: b[o..<(o + 20)].prefix { $0 != 0 }, as: UTF8.self)
        scale = Int(b[o + 20]); layout = Int(b[o + 21]); regionCount = Int(b[o + 22])
        regions = (0..<stored).map { i in
            let s = o + 23 + i * SwayLayout.regionSize
            return Region(bytes: Array(b[s..<(s + SwayLayout.regionSize)]))
        }
        let t = o + 23 + stored * SwayLayout.regionSize
        func arr(_ off: Int, _ n: Int) -> [Int] { b[(t + off)..<(t + off + n)].map(Int.init) }
        func grid(_ off: Int) -> [[Int]] { (0..<8).map { arr(off + $0 * 8, 8) } }
        pads = Pads(rootNotes: arr(0, 16), chordTypes: arr(16, 16), rootOctaves: arr(32, 16),
                    chordInversions: arr(48, 16), channels: arr(64, 16))
        encoders = Encoders(ccNumbers: grid(80), channels: grid(144))
    }

    public func encoded(storedRegions: Int? = nil) -> [UInt8] {
        let stored = storedRegions ?? regions.count
        var out: [UInt8] = []
        out.reserveCapacity(Preset.size(regions: stored))
        // Keep the original 20 name bytes unless the name was edited.
        if let raw = nameRaw, raw.count == 20, String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self) == name {
            out += raw
        } else {
            let utf8 = Array(name.utf8.prefix(19))
            out += utf8 + [UInt8](repeating: 0, count: 20 - utf8.count)
        }
        out += [UInt8(clamping: scale), UInt8(clamping: layout), UInt8(clamping: regionCount)]
        for i in 0..<stored { out += i < regions.count ? regions[i].encoded() : Region.blank }
        func fixed(_ a: [Int], _ n: Int) -> [UInt8] { (0..<n).map { $0 < a.count ? UInt8(clamping: a[$0]) : 0 } }
        out += fixed(pads.rootNotes, 16) + fixed(pads.chordTypes, 16) + fixed(pads.rootOctaves, 16)
        out += fixed(pads.chordInversions, 16) + fixed(pads.channels, 16)
        out += fixed(encoders.ccNumbers.flatMap { $0 }, 64) + fixed(encoders.channels.flatMap { $0 }, 64)
        return out
    }
}

public struct Project: Codable, Equatable {
    public var version: Int
    public var presets: [Preset]
    public var selectedBank: Int
    public var selectedPreset: Int

    /// Decode a project downloaded from the device, or a .swayproj file (`file: true`).
    public init(bytes b: [UInt8], file: Bool = false) throws {
        guard b.count > 4, b[0] == 0xff else { throw SwayError.malformed("not a Sway project (bad marker)") }
        version = Int(b[1])
        var presets: [Preset] = []
        var o = 2
        for _ in 0..<SwayLayout.presetCount {
            guard b.count >= o + 23 else { throw SwayError.malformed("project is truncated") }
            let stored = file ? SwayLayout.fileRegions : Int(b[o + 22])
            presets.append(try Preset(b, at: o, storedRegions: stored))
            o += Preset.size(regions: stored)
        }
        guard o + 2 == b.count else { throw SwayError.malformed("project length mismatch: parsed \(o + 2), have \(b.count)") }
        self.presets = presets
        selectedBank = Int(b[o]); selectedPreset = Int(b[o + 1])
    }

    public func encoded(file: Bool = false) -> [UInt8] {
        var out: [UInt8] = [0xff, UInt8(clamping: version)]
        for p in presets { out += p.encoded(storedRegions: file ? SwayLayout.fileRegions : nil) }
        return out + [UInt8(clamping: selectedBank), UInt8(clamping: selectedPreset)]
    }
}

// MARK: - byte helpers

private func readFloat(_ b: [UInt8], _ o: Int) -> Float {
    Float(bitPattern: UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24)
}

private func writeFloat(_ v: Float, into b: inout [UInt8], at o: Int) {
    let bits = v.bitPattern
    b[o] = UInt8(bits & 0xff); b[o + 1] = UInt8((bits >> 8) & 0xff)
    b[o + 2] = UInt8((bits >> 16) & 0xff); b[o + 3] = UInt8(bits >> 24)
}

private func hexColor<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
    "#" + bytes.map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
}

private func rgb(_ hex: String) -> [UInt8] {
    let digits = Array(hex.drop { $0 == "#" })
    guard digits.count == 6 else { return [0, 0, 0] }
    return stride(from: 0, to: 6, by: 2).map { UInt8(String(digits[$0...($0 + 1)]), radix: 16) ?? 0 }
}
