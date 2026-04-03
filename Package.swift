// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeMeterPro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeMeterPro",
            dependencies: ["Shared"],
            path: "ClaudeMeterPro",
            exclude: ["Info.plist", "ClaudeMeterPro.entitlements"],
            swiftSettings: [.define("MAIN_APP")]
        ),
        // Widget extension — requires Xcode project for actual bundling.
        // See WIDGET-SETUP.md for Xcode integration instructions.
        .target(
            name: "ClaudeMeterWidget",
            dependencies: ["Shared"],
            path: "ClaudeMeterWidget",
            exclude: ["Info.plist", "ClaudeMeterWidget.entitlements"]
        ),
        // Shared code included by both targets
        .target(
            name: "Shared",
            path: "Shared"
        ),
    ]
)
