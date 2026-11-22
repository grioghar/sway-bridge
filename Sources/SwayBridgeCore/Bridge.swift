// Ties the pieces together: keeps the Sway's serial link and MIDI feed alive and
// exposes state + commands to local web pages over a WebSocket.
import Foundation
import Dispatch
import SwayKit

public struct BridgeState: Codable {
    public var connected = false          // serial link up
    public var midiConnected = false
    public var device: DeviceInfo?
    public var selection: PresetSelection?
    public var project: Project?
    public var error: String?
    public init() {}
}

public struct BridgeError: Error, CustomStringConvertible { public var description: String }

public final class Bridge {
    private let server: WebServer
    private let backups: URL
    private let work = DispatchQueue(label: "sway.serial")   // every serial operation runs here
    private var state = BridgeState()                        // touched only on `work`
    private var port: SerialPort?
    private var client: SwayClient?
    private var lastBackup: [UInt8] = []
    private var midi: MIDIListener!
    private let encoder = JSONEncoder()
    private let midiOut = makeMIDISender(matching: "sway")

    /// Hooks for an app embedding the bridge. Set before `start()`; called on the bridge's queue.
    public var onState: ((BridgeState) -> Void)?
    public var onMIDI: (([UInt8]) -> Void)?

    public init(server: WebServer, backups: URL) {
        self.server = server
        self.backups = backups
        encoder.outputFormatting = [.sortedKeys]   // stable output, so pages can compare states
        midi = makeMIDIListener(matching: "sway") { [weak self, weak server] message in
            self?.onMIDI?(message)
            let ms = Int(Date().timeIntervalSince1970 * 1000)
            server?.broadcast("{\"type\":\"midi\",\"t\":\(ms),\"m\":[\(message.map(String.init).joined(separator: ","))]}")
        }
        server.onOpen = { [weak self] connection in
            guard let self else { return }
            self.work.async { connection.send(text: self.stateMessage()) }
        }
        server.onText = { [weak self] connection, text in
            self?.work.async { self?.handle(text, from: connection) }
        }
    }

    public func start() {
        work.async { self.tick(counter: 0) }
    }

    // MARK: - commands from an embedding app (completion runs on the bridge's queue)

    public func reload(completion: @escaping (Error?) -> Void) {
        run({ try self.refresh() }, completion)
    }

    public func setBrightness(_ value: Int, completion: @escaping (Error?) -> Void) {
        run({ try self.applyBrightness(value) }, completion)
    }

    public func writePreset(bank: Int, preset: Int, _ edited: Preset, completion: @escaping (Error?) -> Void) {
        run({ try self.store(edited, bank: bank, preset: preset) }, completion)
    }

    /// Make a preset the active one on the Sway (it switches on receiving a Program Change).
    public func activatePreset(bank: Int, preset: Int, completion: @escaping (Error?) -> Void) {
        run({ try self.activate(bank: bank, preset: preset) }, completion)
    }

    private func run(_ body: @escaping () throws -> Void, _ completion: @escaping (Error?) -> Void) {
        work.async {
            do { try body(); self.publish(); completion(nil) } catch { completion(error) }
        }
    }

    /// Once a second: follow preset changes made on the hardware. Every third second:
    /// look for a Sway that was plugged in or unplugged.
    private func tick(counter: Int) {
        if counter % 3 == 0 {
            connectIfNeeded()
            midi.refresh()
            if midi.isConnected != state.midiConnected {
                state.midiConnected = midi.isConnected
                log(state.midiConnected ? "listening to the Sway's MIDI" : "Sway MIDI gone")
                publish()
            }
        }
        // With pages open, follow the hardware every second; otherwise every third second is
        // enough to notice an unplug.
        if client != nil && (server.clientCount > 0 || onState != nil || counter % 3 == 0) { pollSelection() }
        work.asyncAfter(deadline: .now() + 1) { self.tick(counter: counter + 1) }
    }

    // MARK: - serial link

    private func connectIfNeeded() {
        guard client == nil, let path = findSwayPort() else { return }
        do {
            let port = try SerialPort(path: path)
            let client = SwayClient(transport: port)
            do {
                state.device = try client.handshake()
            } catch {
                port.close()
                throw BridgeError(description: "Sway found on \(path) but not answering (\(error)). Unplug and replug it.")
            }
            self.port = port
            self.client = client
            state.connected = true
            state.error = nil
            log("Sway connected on \(path): firmware \(state.device?.firmware ?? "?")\(state.device?.lowPower == true ? " (low power)" : "")")
            try refresh()
        } catch let error as SerialError where error.busy {
            setError("Cannot open \(path): another app (The Sway?) is using it")
        } catch {
            setError("\(error)")
            if client != nil { publish() }
        }
    }

    private func disconnect(_ reason: String) {
        log("serial link lost: \(reason)")
        port?.close()
        port = nil; client = nil
        state.connected = false
        state.device = nil
        publish()
    }

    private func setError(_ message: String) {
        guard state.error != message else { return }
        state.error = message
        log(message)
        publish()
    }

    /// Run a device operation; a transport failure drops the link so it is re-established.
    private func withClient<T>(_ body: (SwayClient) throws -> T) throws -> T {
        guard let client else { throw BridgeError(description: "Sway is not connected") }
        do { return try body(client) } catch let error as SerialError {
            disconnect(error.description)
            throw error
        } catch SwayError.noAnswer(let command) {
            disconnect("no answer")
            throw SwayError.noAnswer(command: command)
        }
    }

    private func refresh() throws {
        try withClient { client in
            state.selection = try client.selection()
            let raw = try client.readProject()
            state.project = try Project(bytes: raw)
            backup(raw, name: "project")
        }
        publish()
    }

    private func pollSelection() {
        guard let selection = try? withClient({ try $0.selection() }), selection != state.selection else { return }
        state.selection = selection
        publish()
    }

    private func backup(_ raw: [UInt8], name: String) {
        if name == "project" {
            if lastBackup.isEmpty { lastBackup = newestProjectBackup() }
            guard raw != lastBackup else { return }
            lastBackup = raw
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        try? FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
        try? Data(raw).write(to: backups.appendingPathComponent("\(name)-\(formatter.string(from: Date())).bin"))
    }

    private func newestProjectBackup() -> [UInt8] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: backups.path)) ?? []
        guard let newest = names.filter({ $0.hasPrefix("project-") }).sorted().last,
              let data = try? Data(contentsOf: backups.appendingPathComponent(newest)) else { return [] }
        return [UInt8](data)
    }

    // MARK: - commands from pages

    private func handle(_ text: String, from connection: WebSocketConnection) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let method = object["method"] as? String else { return }
        let id = object["id"].flatMap { try? JSONSerialization.data(withJSONObject: [$0]) }
            .map { String(decoding: $0, as: UTF8.self).dropFirst().dropLast() }.map(String.init) ?? "null"
        let params = object["params"] as? [String: Any] ?? [:]
        do {
            try perform(method, params)
            connection.send(text: "{\"type\":\"result\",\"id\":\(id),\"result\":true}")
        } catch {
            let message = (try? JSONSerialization.data(withJSONObject: ["\(error)"])).map { String(decoding: $0, as: UTF8.self).dropFirst().dropLast() } ?? "\"error\""
            connection.send(text: "{\"type\":\"result\",\"id\":\(id),\"error\":\(message)}")
        }
    }

    private func perform(_ method: String, _ params: [String: Any]) throws {
        func int(_ key: String, _ range: ClosedRange<Int>) throws -> Int {
            guard let value = params[key] as? Int, range.contains(value) else { throw BridgeError(description: "bad or missing '\(key)'") }
            return value
        }
        switch method {
        case "getState":
            break
        case "refresh":
            try refresh()
        case "activatePreset":
            try activate(bank: try int("bank", 0...5), preset: try int("preset", 0...5))
        case "setBrightness":
            try applyBrightness(try int("value", 0...255))
        case "writePreset":
            let bank = try int("bank", 0...5), preset = try int("preset", 0...5)
            guard let data = params["data"], let json = try? JSONSerialization.data(withJSONObject: data),
                  let edited = try? JSONDecoder().decode(Preset.self, from: json) else { throw BridgeError(description: "bad or missing 'data'") }
            try store(edited, bank: bank, preset: preset)
        default:
            throw BridgeError(description: "unknown method \(method)")
        }
        publish()
    }

    /// Program Change 0-35 selects bank * 6 + preset (found by experiment on firmware 1.3.0;
    /// 36 and 37 are sleep and wake). Confirmed afterwards over the serial link.
    private func activate(bank: Int, preset: Int) throws {
        guard (0...5).contains(bank), (0...5).contains(preset) else { throw BridgeError(description: "no such preset slot") }
        try midiOut.send([0xc0, UInt8(bank * SwayLayout.presetsPerBank + preset)])
        Thread.sleep(forTimeInterval: 0.3)
        let now = try withClient { try $0.selection() }
        state.selection = now
        guard now == PresetSelection(bank: bank, preset: preset) else {
            throw BridgeError(description: "the Sway did not switch preset (is its firmware 1.3.0 or later?)")
        }
    }

    private func applyBrightness(_ value: Int) throws {
        guard (0...255).contains(value) else { throw BridgeError(description: "brightness out of range") }
        try withClient { try $0.setBrightness(value) }
        state.device?.brightness = value
    }

    /// Write one preset to the Sway, then read it back and confirm it took.
    private func store(_ edited: Preset, bank: Int, preset: Int) throws {
        guard (0...5).contains(bank), (0...5).contains(preset) else { throw BridgeError(description: "no such preset slot") }
        let index = bank * SwayLayout.presetsPerBank + preset
        guard let project = state.project, index < project.presets.count else { throw BridgeError(description: "no project loaded") }
        let bytes = edited.encoded()
        backup(project.presets[index].encoded(), name: "preset-b\(bank)p\(preset)-before")
        // The Sway only lets us read back the *active* preset on its own, so verify by
        // re-reading the whole project and checking this slot.
        try withClient { client in
            try client.writePreset(bank: bank, preset: preset, bytes: bytes)
            let raw = try client.readProject()
            let fresh = try Project(bytes: raw)
            guard index < fresh.presets.count, fresh.presets[index].encoded() == bytes else {
                throw BridgeError(description: "Sway did not store the preset as sent")
            }
            state.project = fresh
            state.selection = try client.selection()   // an upload makes the Sway switch to that preset
            backup(raw, name: "project")
        }
    }

    // MARK: - publishing

    private func stateMessage() -> String {
        let json = (try? encoder.encode(state)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return "{\"type\":\"state\",\"state\":\(json)}"
    }

    private func publish() {
        server.broadcast(stateMessage())
        onState?(state)
    }
}

public func log(_ message: String) {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm:ss"
    print("\(formatter.string(from: Date())) \(message)")
    fflush(stdout)
}
