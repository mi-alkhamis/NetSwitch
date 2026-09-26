// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "netswitch-cli",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(path: "../Packages/NetSwitchCore")
    ],
    targets: [
        .executableTarget(
            name: "netswitch",
            dependencies: ["NetSwitchCore"],
            path: "Sources/netswitch",
            exclude: ["Net.swift", "Profile.swift", "ProfileStore.swift", "Util.swift"],
            sources: ["main.swift"]
        )
    ]
)
