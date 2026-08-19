// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetSwitchCore",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "NetSwitchCore", targets: ["NetSwitchCore"])
    ],
    targets: [
        .target(name: "NetSwitchCore"),
        .testTarget(name: "NetSwitchCoreTests", dependencies: ["NetSwitchCore"])
    ]
)
