// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DClutterKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DClutterCore", targets: ["DClutterCore"]),
        .library(name: "DClutterPlatform", targets: ["DClutterPlatform"]),
    ],
    targets: [
        // Pure logic. Foundation + UniformTypeIdentifiers only — no AppKit, ever.
        .target(name: "DClutterCore"),

        // macOS-specific implementations of DClutterCore's protocols.
        .target(name: "DClutterPlatform", dependencies: ["DClutterCore"]),

        .testTarget(name: "DClutterCoreTests", dependencies: ["DClutterCore"]),
    ]
)
