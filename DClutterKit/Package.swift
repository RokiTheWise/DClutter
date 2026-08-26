// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DClutterKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DClutterCore", targets: ["DClutterCore"]),
        .library(name: "DClutterPlatform", targets: ["DClutterPlatform"]),
        .library(name: "DClutterUI", targets: ["DClutterUI"]),
    ],
    targets: [
        // Pure logic. Foundation + UniformTypeIdentifiers only — no AppKit, ever.
        .target(name: "DClutterCore"),

        // macOS-specific implementations of DClutterCore's protocols.
        .target(name: "DClutterPlatform", dependencies: ["DClutterCore"]),

        // SwiftUI views and design tokens.
        .target(name: "DClutterUI", dependencies: ["DClutterCore", "DClutterPlatform"]),

        .testTarget(name: "DClutterCoreTests", dependencies: ["DClutterCore"]),
        .testTarget(name: "DClutterPlatformTests", dependencies: ["DClutterPlatform"]),
    ]
)
