// Live MIDI from the Sway, turned into "which control is moving" for the editor.
// Messages arrive on a MIDI thread; they are applied on the main thread at most 30 times a
// second so a busy performance does not redraw the whole window per message.
import Foundation
import SwayKit

/// Lookup from a MIDI message to the controls of one preset that produce it.
struct MIDIMap {
    enum Role { case x, y, sway, pulse, press, note }
    enum Target: Hashable {
        case pad(Int)
        case dial(page: Int, index: Int)
        case region(Int, Role)

        var id: String {
            switch self {
            case .pad(let i): return "pad-\(i)"
            case .dial(let page, let i): return "dial-\(page)-\(i)"
            case .region(let i, _): return "region-\(i)"
            }
        }
    }

    private var exactCC: [Int: [Target]] = [:]   // channel << 8 | number
    private var anyCC: [Int: [Target]] = [:]     // number (region CCs carry no channel we can name yet)
    private var notes: [Int: [Target]] = [:]     // channel << 8 | note

    init(_ preset: Preset?) {
        guard let preset else { return }
        for (page, row) in preset.encoders.ccNumbers.enumerated() {
            for (index, number) in row.enumerated() where page < preset.encoders.channels.count && index < preset.encoders.channels[page].count {
                exactCC[preset.encoders.channels[page][index] << 8 | number, default: []].append(.dial(page: page, index: index))
            }
        }
        let pads = preset.pads
        for index in pads.rootNotes.indices where index < pads.channels.count && index < pads.rootOctaves.count {
            notes[pads.channels[index] << 8 | (pads.rootOctaves[index] * 12 + pads.rootNotes[index]), default: []].append(.pad(index))
        }
        for (index, r) in preset.regions.prefix(preset.regionCount).enumerated() {
            let roles: [(Role, [Int?])] = [(.x, [r.ccX, r.ccX2]), (.y, [r.ccY, r.ccY2]), (.sway, [r.swayCc]), (.pulse, [r.pulseCc]), (.press, [r.pressCc])]
            for (role, numbers) in roles {
                for number in Set(numbers.compactMap { $0 }) { anyCC[number, default: []].append(.region(index, role)) }
            }
            for (i, note) in r.notes.enumerated() {
                let channel = i < r.noteChannels.count ? r.noteChannels[i] : 0
                notes[channel << 8 | note, default: []].append(.region(index, .note))
            }
        }
    }

    /// Controls behind a message, with its value and (for notes) whether it is a note-on.
    func lookup(_ m: [UInt8]) -> (targets: [Target], value: Int, on: Bool?) {
        guard m.count >= 3 else { return ([], 0, nil) }
        let type = m[0] & 0xf0, channel = Int(m[0] & 0x0f), number = Int(m[1]), value = Int(m[2])
        switch type {
        case 0xb0:
            // An exact dial match on (channel, cc) wins unless only a region uses that number.
            return (exactCC[channel << 8 | number] ?? anyCC[number] ?? [], value, nil)
        case 0x90, 0x80:
            return (notes[channel << 8 | number] ?? [], value, type == 0x90 && value > 0)
        default:
            return ([], 0, nil)
        }
    }
}

final class LiveFeed: ObservableObject {
    struct Hand: Equatable {
        var x: Int?
        var y: Int?
        var at = Date()
    }

    /// Control id -> when it last moved (far future while a note is held).
    @Published private(set) var hot: [String: Date] = [:]
    /// Region index -> latest X / Y values.
    @Published private(set) var hands: [Int: Hand] = [:]
    /// Dial index -> last value seen, and the dial page it was sent from.
    @Published private(set) var dials: [Int: Int] = [:]
    @Published private(set) var dialPage: Int?
    var map = MIDIMap(nil)                      // main thread only

    private var pending: [[UInt8]] = []
    private let lock = NSLock()
    private var timer: Timer?

    init() {
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.drain() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func push(_ message: [UInt8]) {
        lock.lock(); pending.append(message); lock.unlock()
    }

    func isHot(_ id: String) -> Bool { hot[id] != nil }

    private func drain() {
        lock.lock()
        let batch = pending
        pending.removeAll(keepingCapacity: true)
        lock.unlock()
        guard !batch.isEmpty || !hot.isEmpty || !hands.isEmpty else { return }

        let now = Date()
        var hot = self.hot, hands = self.hands, dials = self.dials, page = dialPage
        for message in batch {
            let hit = map.lookup(message)
            // Provisional: the eight small buttons appear to send notes 0-7 on channel 2.
            if hit.targets.isEmpty, message.count >= 3, message[0] & 0xef == 0x81, message[1] < 8 {
                hot["button-\(message[1])"] = message[0] & 0xf0 == 0x90 && message[2] > 0 ? .distantFuture : now
            }
            for target in hit.targets {
                // Notes stay lit while held; everything else fades shortly after it stops moving.
                hot[target.id] = hit.on == true ? .distantFuture : now
                if case .dial(let p, let index) = target { dials[index] = hit.value; page = p }
                if case .region(let index, let role) = target, role == .x || role == .y {
                    var hand = hands[index] ?? Hand()
                    if role == .x { hand.x = hit.value } else { hand.y = hit.value }
                    hand.at = now
                    hands[index] = hand
                }
            }
        }
        hot = hot.filter { now.timeIntervalSince($0.value) < 0.2 }
        hands = hands.filter { now.timeIntervalSince($0.value.at) < 1.5 }
        if hot != self.hot { self.hot = hot }
        if hands != self.hands { self.hands = hands }
        if dials != self.dials { self.dials = dials }
        if page != dialPage { dialPage = page }
    }
}
