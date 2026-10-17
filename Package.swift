// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeowTimer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MeowTimer",
            path: "Sources"
        )
    ]
)
