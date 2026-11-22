// swift-tools-version:5.9
import PackageDescription

// No third-party dependencies: everything builds with the stock Swift toolchain
// on macOS, Linux and Windows.
let package = Package(
    name: "SwayBridge",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwayKit", targets: ["SwayKit"]),
        .executable(name: "sway-bridge", targets: ["sway-bridge"]),
    ],
    targets: [
        .target(name: "SwayKit"),
        .executableTarget(
            name: "sway-bridge",
            dependencies: ["SwayKit"],
            linkerSettings: [
                .linkedFramework("CoreMIDI", .when(platforms: [.macOS])),
                .linkedLibrary("winmm", .when(platforms: [.windows])),
                .linkedLibrary("ws2_32", .when(platforms: [.windows])),
            ]
        ),
        .testTarget(name: "SwayKitTests", dependencies: ["SwayKit"]),
    ],
    swiftLanguageVersions: [.v5]
)
