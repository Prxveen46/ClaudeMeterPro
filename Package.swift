// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeMeterPro",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeMeterPro",
            path: "ClaudeMeterPro",
            exclude: ["Info.plist", "ClaudeMeterPro.entitlements"]
        )
    ]
)
