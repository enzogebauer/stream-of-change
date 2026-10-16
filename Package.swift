// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StreamOfChange",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "StreamOfChange", path: "Sources")
    ]
)
