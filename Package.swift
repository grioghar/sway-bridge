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
        .target(
            name: "SwayBridgeCore",
            dependencies: ["SwayKit"],
            linkerSettings: [
                .linkedFramework("CoreMIDI", .when(platforms: [.macOS])),
                .linkedLibrary("winmm", .when(platforms: [.windows])),
                .linkedLibrary("ws2_32", .when(platforms: [.windows])),
            ]
        ),
        .executableTarget(name: "sway-bridge", dependencies: ["SwayBridgeCore"]),
        .testTarget(name: "SwayKitTests", dependencies: ["SwayKit"]),
    ],
    swiftLanguageVersions: [.v5]
)

// The native configurator app is macOS only (SwiftUI); scripts/build-mac.sh bundles it as Sway Bridge.app.
#if os(macOS)
package.products.append(.executable(name: "SwayApp", targets: ["SwayApp"]))
package.targets.append(.executableTarget(name: "SwayApp", dependencies: ["SwayKit", "SwayBridgeCore"]))
#endif
