// sway-bridge: local companion for the Audima Sway.
//   sway-bridge [--port 7729] [--web <dir>] [--backups <dir>]
import Foundation
import Dispatch

var port = 7729
var webDirectory: String?
var backupDirectory: String?
var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let argument = arguments.next() {
    switch argument {
    case "--port": port = arguments.next().flatMap { Int($0) } ?? port
    case "--web": webDirectory = arguments.next()
    case "--backups": backupDirectory = arguments.next()
    case "-h", "--help":
        print("usage: sway-bridge [--port 7729] [--web <dir>] [--backups <dir>]")
        exit(0)
    default:
        FileHandle.standardError.write(Data("unknown option \(argument)\n".utf8))
        exit(2)
    }
}

// The web pages live in ./web next to where the bridge is started, unless told otherwise.
let working = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let webRoot = webDirectory.map { URL(fileURLWithPath: $0) } ?? working.appendingPathComponent("web")
let backups = backupDirectory.map { URL(fileURLWithPath: $0) } ?? working.appendingPathComponent("backups")

let server = WebServer(port: port, webRoot: webRoot)
do {
    try server.start()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
let bridge = Bridge(server: server, backups: backups)
log("Sway bridge on http://localhost:\(port)  (config: /config/  overlay: /overlay/)")
if !FileManager.default.fileExists(atPath: webRoot.path) { log("warning: web directory \(webRoot.path) not found") }
bridge.start()
dispatchMain()
