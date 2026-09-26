// swift-tools-version: 5.9
import PackageDescription

// The app builds with the Xcode project. This package tests the audio math independently.
let package = Package(
    name: "CaelestiaCore",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CaelestiaCore", path: "CaelestiaNotch/Core"),
        .testTarget(name: "CaelestiaCoreTests", dependencies: ["CaelestiaCore"], path: "Tests"),
    ]
)
