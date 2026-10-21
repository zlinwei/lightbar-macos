// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-only
import PackageDescription
let package = Package(name: "MiLightBar", platforms: [.macOS(.v14)], products: [.executable(name: "MiLightBar", targets: ["MiLightBar"])], targets: [
    .target(name: "LightBarCore"),
    .executableTarget(name: "MiLightBar", dependencies: ["LightBarCore"]),
    .testTarget(name: "LightBarCoreTests", dependencies: ["LightBarCore", "MiLightBar"])
])
