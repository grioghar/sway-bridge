// Serial port access for the Sway (a USB CDC device, so baud rate is irrelevant).
import Foundation
import SwayKit

#if os(Windows)
import WinSDK
#elseif canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

struct SerialError: Error, CustomStringConvertible {
    var description: String
    var busy = false
}

#if os(Windows)

final class SerialPort: SwayTransport {
    private var handle: HANDLE?

    init(path: String) throws {
        // COM10 and above need the \\.\ prefix; it is harmless for the rest.
        let h = ("\\\\.\\" + path).withCString(encodedAs: UTF16.self) {
            CreateFileW($0, DWORD(GENERIC_READ) | DWORD(GENERIC_WRITE), 0, nil, DWORD(OPEN_EXISTING), 0, nil)
        }
        guard let h, h != INVALID_HANDLE_VALUE else {
            let code = GetLastError()
            throw SerialError(description: "cannot open \(path) (error \(code))", busy: code == DWORD(ERROR_ACCESS_DENIED))
        }
        handle = h
        // Return from ReadFile as soon as any bytes arrive, or after 100 ms.
        var timeouts = COMMTIMEOUTS(ReadIntervalTimeout: DWORD.max, ReadTotalTimeoutMultiplier: DWORD.max,
                                    ReadTotalTimeoutConstant: 100, WriteTotalTimeoutMultiplier: 0,
                                    WriteTotalTimeoutConstant: 1000)
        SetCommTimeouts(h, &timeouts)
        EscapeCommFunction(h, DWORD(SETDTR))   // CDC devices only talk while DTR is asserted
        EscapeCommFunction(h, DWORD(SETRTS))
        PurgeComm(h, DWORD(PURGE_RXCLEAR))
    }

    func send(_ bytes: [UInt8]) throws {
        guard let handle else { throw SerialError(description: "port is closed") }
        var written: DWORD = 0
        let ok = bytes.withUnsafeBytes { WriteFile(handle, $0.baseAddress, DWORD(bytes.count), &written, nil) }
        guard ok, written == DWORD(bytes.count) else { throw SerialError(description: "write failed (error \(GetLastError()))") }
    }

    func receive(timeout: Double) throws -> [UInt8] {
        guard let handle else { throw SerialError(description: "port is closed") }
        var buffer = [UInt8](repeating: 0, count: 512)
        var got: DWORD = 0
        let ok = buffer.withUnsafeMutableBytes { ReadFile(handle, $0.baseAddress, DWORD($0.count), &got, nil) }
        guard ok else { throw SerialError(description: "read failed (error \(GetLastError()))") }
        return Array(buffer.prefix(Int(got)))
    }

    func close() {
        if let handle { CloseHandle(handle) }
        handle = nil
    }

    deinit { close() }
}

#else

#if canImport(Darwin)
private let exclusiveRequest: UInt = 0x2000_740d   // TIOCEXCL
#else
private let exclusiveRequest: UInt = 0x540c        // TIOCEXCL
#endif

final class SerialPort: SwayTransport {
    private var fd: Int32 = -1

    init(path: String) throws {
        // Non-blocking open so a port without carrier cannot stall us.
        fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else {
            throw SerialError(description: "cannot open \(path): \(String(cString: strerror(errno)))", busy: errno == EBUSY)
        }
        // Same exclusive claim the official app makes, so the two cannot interleave.
        _ = ioctl(fd, exclusiveRequest)
        var tio = termios()
        tcgetattr(fd, &tio)
        cfmakeraw(&tio)
        tio.c_cflag |= tcflag_t(CLOCAL | CREAD)
        tcsetattr(fd, TCSANOW, &tio)
        tcflush(fd, TCIOFLUSH)
    }

    func send(_ bytes: [UInt8]) throws {
        guard fd >= 0 else { throw SerialError(description: "port is closed") }
        var offset = 0
        var stalls = 0
        while offset < bytes.count {
            let n = bytes[offset...].withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
            if n > 0 { offset += n; continue }
            guard n < 0, errno == EAGAIN || errno == EINTR, stalls < 100 else {
                throw SerialError(description: "write failed: \(String(cString: strerror(errno)))")
            }
            stalls += 1
            var p = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            _ = poll(&p, 1, 10)
        }
    }

    func receive(timeout: Double) throws -> [UInt8] {
        guard fd >= 0 else { throw SerialError(description: "port is closed") }
        var p = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let ready = poll(&p, 1, Int32(timeout * 1000))
        if ready == 0 { return [] }
        if ready < 0 {
            if errno == EINTR { return [] }
            throw SerialError(description: "poll failed: \(String(cString: strerror(errno)))")
        }
        if p.revents & Int16(POLLHUP | POLLERR | POLLNVAL) != 0 && p.revents & Int16(POLLIN) == 0 {
            throw SerialError(description: "Sway disconnected")
        }
        var buffer = [UInt8](repeating: 0, count: 512)
        let n = buffer.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
        if n > 0 { return Array(buffer.prefix(n)) }
        if n < 0 && (errno == EAGAIN || errno == EINTR) { return [] }
        throw SerialError(description: "Sway disconnected")
    }

    func close() {
        if fd >= 0 { _ = Foundation.close(fd) }
        fd = -1
    }

    deinit { close() }
}

#endif

/// Locate the Sway's serial port by its USB identity (vendor 0483, product 52a4).
func findSwayPort() -> String? {
    #if os(macOS)
    guard let listing = run("/usr/sbin/ioreg", ["-p", "IOUSB", "-l", "-w0"]) else { return nil }
    for block in listing.components(separatedBy: "+-o ") where block.contains("\"USB Vendor Name\" = \"Audima Labs\"") {
        guard let range = block.range(of: "\"USB Serial Number\" = \"") else { continue }
        let serial = block[range.upperBound...].prefix { $0 != "\"" }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
        if let name = names.first(where: { $0.hasPrefix("cu.usbmodem\(serial)") }) { return "/dev/" + name }
    }
    return nil
    #elseif os(Linux)
    let dir = "/dev/serial/by-id"
    let names = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
    guard let name = names.first(where: { $0.contains("Audima") || $0.contains("Sway") }) else { return nil }
    return URL(fileURLWithPath: dir + "/" + name).resolvingSymlinksInPath().path
    #elseif os(Windows)
    // The USB device's registry entry records which COM port it was given.
    let key = "HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB\\VID_0483&PID_52A4"
    guard let listing = run("C:\\Windows\\System32\\reg.exe", ["query", key, "/s", "/v", "PortName"]) else { return nil }
    let present = Set((run("C:\\Windows\\System32\\reg.exe", ["query", "HKLM\\HARDWARE\\DEVICEMAP\\SERIALCOMM"]) ?? "")
        .split(whereSeparator: { $0 == " " || $0 == "\r" || $0 == "\n" }).filter { $0.hasPrefix("COM") }.map(String.init))
    for line in listing.split(whereSeparator: \.isNewline) where line.contains("PortName") {
        if let port = line.split(separator: " ").last.map(String.init), present.contains(port) { return port }
    }
    return nil
    #else
    return nil
    #endif
}

private func run(_ tool: String, _ arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}
