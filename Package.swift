// swift-tools-version: 5.9
import PackageDescription

// The app builds with Xcode. This package tests independent audio and lyrics logic.
let package = Package(
    name: "CaelestiaCore",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CaelestiaCore", path: "CaelestiaNotch/Core"),
        .testTarget(name: "CaelestiaCoreTests", dependencies: ["CaelestiaCore"], path: "Tests"),
    ]
)
