// A minimal localhost-only HTTP + WebSocket server on plain sockets, so the bridge
// needs no third-party networking library on any platform. One thread per connection.
import Foundation
import SwayKit

#if os(Windows)
import WinSDK
private typealias SocketHandle = SOCKET
private let invalidSocket: SocketHandle = INVALID_SOCKET
private func closeSocket(_ s: SocketHandle) { closesocket(s) }
#else
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
private typealias SocketHandle = Int32
private let invalidSocket: SocketHandle = -1
private func closeSocket(_ s: SocketHandle) { close(s) }
#endif

/// One connected WebSocket client.
final class WebSocketConnection {
    fileprivate let socket: SocketHandle
    private let writeLock = NSLock()
    fileprivate(set) var isOpen = true

    fileprivate init(socket: SocketHandle) { self.socket = socket }

    func send(text: String) {
        let payload = Array(text.utf8)
        var frame: [UInt8] = [0x81]
        switch payload.count {
        case 0..<126: frame.append(UInt8(payload.count))
        case 126..<65536: frame += [126, UInt8(payload.count >> 8), UInt8(payload.count & 0xff)]
        default: frame += [127] + (0..<8).map { UInt8((UInt64(payload.count) >> UInt64(56 - 8 * $0)) & 0xff) }
        }
        sendFrame(frame + payload)
    }

    /// Control frames (pong) carry at most 125 bytes.
    fileprivate func sendControl(_ first: UInt8, _ payload: [UInt8]) {
        guard payload.count < 126 else { return }
        sendFrame([first, UInt8(payload.count)] + payload)
    }

    private func sendFrame(_ frame: [UInt8]) {
        writeLock.lock(); defer { writeLock.unlock() }
        if isOpen && !sendAll(socket, frame) { isOpen = false }
    }
}

public final class WebServer {
    let port: Int
    let webRoot: URL
    var onOpen: (WebSocketConnection) -> Void = { _ in }
    var onText: (WebSocketConnection, String) -> Void = { _, _ in }

    private let lock = NSLock()
    private var connections: [WebSocketConnection] = []

    public init(port: Int, webRoot: URL) {
        self.port = port
        self.webRoot = webRoot.standardizedFileURL
    }

    var clientCount: Int { lock.lock(); defer { lock.unlock() }; return connections.count }

    func broadcast(_ text: String) {
        lock.lock(); let targets = connections; lock.unlock()
        for c in targets { c.send(text: text) }
    }

    /// Binds 127.0.0.1 only and serves forever on background threads.
    public func start() throws {
        #if os(Windows)
        var wsa = WSADATA()
        WSAStartup(0x0202, &wsa)
        #else
        signal(SIGPIPE, SIG_IGN)
        #endif
        #if os(Linux)
        let streamType = Int32(SOCK_STREAM.rawValue)
        #else
        let streamType = SOCK_STREAM
        #endif
        let listener = socket(AF_INET, streamType, 0)
        guard listener != invalidSocket else { throw SerialError(description: "cannot create socket") }
        var yes: Int32 = 1
        _ = withUnsafeBytes(of: &yes) {
            setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, $0.baseAddress?.assumingMemoryBound(to: CChar.self), socklen_t($0.count))
        }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(port).bigEndian
        address.sin_addr.s_addr = UInt32(0x7f00_0001).bigEndian   // 127.0.0.1
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(listener, 16) == 0 else {
            closeSocket(listener)
            throw SerialError(description: "port \(port) is already in use (is another sway-bridge running?)")
        }
        Thread.detachNewThread { [self] in
            while true {
                let client = accept(listener, nil, nil)
                guard client != invalidSocket else { continue }
                Thread.detachNewThread { self.serve(client) }
            }
        }
    }

    // MARK: - one connection

    private func serve(_ socket: SocketHandle) {
        defer { closeSocket(socket) }
        guard let head = readHead(socket) else { return }
        let lines = head.components(separatedBy: "\r\n")
        let request = lines[0].split(separator: " ")
        guard request.count >= 2, request[0] == "GET" else { return respond(socket, 405, "text/plain", Array("method not allowed".utf8)) }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        // Refuse requests that reached us under another name (DNS rebinding) or from another site.
        guard isLocal(host: headers["host"]) else { return respond(socket, 403, "text/plain", Array("forbidden".utf8)) }
        let path = String(request[1].prefix { $0 != "?" })

        if path == "/ws" {
            guard headers["upgrade"]?.lowercased() == "websocket", let key = headers["sec-websocket-key"],
                  isLocal(origin: headers["origin"]) else { return respond(socket, 403, "text/plain", Array("forbidden".utf8)) }
            let accept = Data(sha1(Array((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))).base64EncodedString()
            let reply = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\n\r\n"
            guard sendAll(socket, Array(reply.utf8)) else { return }
            let connection = WebSocketConnection(socket: socket)
            lock.lock(); connections.append(connection); lock.unlock()
            onOpen(connection)
            readFrames(connection)
            connection.isOpen = false
            lock.lock(); connections.removeAll { $0 === connection }; lock.unlock()
            return
        }
        serveFile(socket, path)
    }

    private func isLocal(host: String?) -> Bool {
        guard let name = host?.split(separator: ":").first.map(String.init) else { return false }
        return name == "localhost" || name == "127.0.0.1"
    }

    private func isLocal(origin: String?) -> Bool {
        guard let origin, origin != "null" else { return true }   // non-browser clients, file:// pages
        if origin.hasPrefix("file:") { return true }
        guard let url = URL(string: origin), let host = url.host else { return false }
        return host == "localhost" || host == "127.0.0.1"
    }

    private func serveFile(_ socket: SocketHandle, _ rawPath: String) {
        var path = rawPath.removingPercentEncoding ?? rawPath
        if path == "/" { path = "/config/" }
        if path.hasSuffix("/") { path += "index.html" }
        let file = webRoot.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
        guard file.path.hasPrefix(webRoot.path + "/"), let data = try? Data(contentsOf: file) else {
            return respond(socket, 404, "text/plain", Array("not found".utf8))
        }
        let types = ["html": "text/html; charset=utf-8", "js": "text/javascript", "css": "text/css", "svg": "image/svg+xml",
                     "json": "application/json", "png": "image/png", "woff2": "font/woff2"]
        respond(socket, 200, types[file.pathExtension.lowercased()] ?? "application/octet-stream", [UInt8](data))
    }

    private func respond(_ socket: SocketHandle, _ status: Int, _ type: String, _ body: [UInt8]) {
        let reason = [200: "OK", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed"][status] ?? "Error"
        let head = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
        _ = sendAll(socket, Array(head.utf8) + body)
    }

    private func readHead(_ socket: SocketHandle) -> String? {
        var bytes: [UInt8] = []
        while bytes.count < 16384 {
            guard let chunk = receive(socket, 1), let b = chunk.first else { return nil }
            bytes.append(b)
            if bytes.suffix(4) == [13, 10, 13, 10] { return String(decoding: bytes.dropLast(4), as: UTF8.self) }
        }
        return nil
    }

    private func readFrames(_ connection: WebSocketConnection) {
        let socket = connection.socket
        var message: [UInt8] = []
        while true {
            guard let head = receiveExactly(socket, 2) else { return }
            let final = head[0] & 0x80 != 0, opcode = head[0] & 0x0f
            let masked = head[1] & 0x80 != 0
            var length = Int(head[1] & 0x7f)
            if length == 126 {
                guard let e = receiveExactly(socket, 2) else { return }
                length = Int(e[0]) << 8 | Int(e[1])
            } else if length == 127 {
                guard let e = receiveExactly(socket, 8) else { return }
                length = e.reduce(0) { $0 << 8 | Int($1) }
            }
            guard masked, length <= 4 << 20, let mask = receiveExactly(socket, 4),
                  var payload = length == 0 ? [] : receiveExactly(socket, length) else { return }
            for i in payload.indices { payload[i] ^= mask[i % 4] }
            switch opcode {
            case 0x8: return                                              // close
            case 0x9: connection.sendControl(0x8a, payload)               // ping -> pong
            case 0xa: break                                               // pong
            case 0x0, 0x1:
                message += payload
                guard message.count <= 4 << 20 else { return }
                if final { onText(connection, String(decoding: message, as: UTF8.self)); message = [] }
            default: return
            }
        }
    }
}

// MARK: - socket helpers

private func sendAll(_ socket: SocketHandle, _ bytes: [UInt8]) -> Bool {
    var offset = 0
    while offset < bytes.count {
        let n = bytes[offset...].withUnsafeBytes { raw -> Int in
            #if os(Windows)
            return Int(send(socket, raw.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(raw.count), 0))
            #else
            return send(socket, raw.baseAddress, raw.count, 0)
            #endif
        }
        guard n > 0 else { return false }
        offset += n
    }
    return true
}

private func receive(_ socket: SocketHandle, _ max: Int) -> [UInt8]? {
    var buffer = [UInt8](repeating: 0, count: max)
    let n = buffer.withUnsafeMutableBytes { raw -> Int in
        #if os(Windows)
        return Int(recv(socket, raw.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(raw.count), 0))
        #else
        return recv(socket, raw.baseAddress, raw.count, 0)
        #endif
    }
    return n > 0 ? Array(buffer.prefix(n)) : nil
}

private func receiveExactly(_ socket: SocketHandle, _ count: Int) -> [UInt8]? {
    var out: [UInt8] = []
    out.reserveCapacity(count)
    while out.count < count {
        guard let chunk = receive(socket, count - out.count) else { return nil }
        out += chunk
    }
    return out
}
