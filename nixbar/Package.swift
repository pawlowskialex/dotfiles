// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NixBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "CTerminal",
            path: "Sources/CTerminal",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "NixBar",
            dependencies: ["CTerminal"]
        ),
    ]
)
