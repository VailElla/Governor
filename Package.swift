// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacPower",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "MacPowerCore", targets: ["MacPowerCore"]),
        .executable(name: "MacPower", targets: ["MacPower"]),
    ],
    targets: [
        .target(
            name: "MacPowerCore",
            path: "Sources/MacPowerCore"
        ),
        .executableTarget(
            name: "MacPower",
            dependencies: ["MacPowerCore"],
            path: "Sources/MacPower"
        ),
        .testTarget(
            name: "MacPowerCoreTests",
            dependencies: ["MacPowerCore"],
            path: "Tests/MacPowerCoreTests"
        ),
        .testTarget(
            name: "MacPowerServiceTests",
            dependencies: ["MacPower"],
            path: "Tests/MacPowerServiceTests"
        ),
    ]
)
