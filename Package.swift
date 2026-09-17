// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Cadence",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "Cadence", targets: ["Cadence"]),
        .library(name: "CadenceHaptics", targets: ["CadenceHaptics"]),
    ],
    targets: [
        .target(name: "CadenceCore"),
        .target(name: "CadenceHaptics", dependencies: ["CadenceCore"]),
        .target(name: "CadenceMotion", dependencies: ["CadenceCore"]),
        .target(name: "Cadence", dependencies: ["CadenceCore", "CadenceHaptics", "CadenceMotion"]),
        .testTarget(name: "CadenceCoreTests", dependencies: ["CadenceCore"]),
    ]
)
