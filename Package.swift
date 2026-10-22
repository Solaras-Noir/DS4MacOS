// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [
    .library(name: "DualSenseCore", targets: ["DualSenseCore"]),
]

var targets: [Target] = [
    .target(name: "DualSenseCore"),
    .testTarget(
        name: "DualSenseCoreTests",
        dependencies: ["DualSenseCore"],
        resources: [.copy("Fixtures")]
    ),
]

#if os(macOS)
products.append(.library(name: "DS4Mac", targets: ["DS4Mac"]))
products.append(.executable(name: "ds4probe", targets: ["ds4probe"]))
products.append(.executable(name: "ds4macos", targets: ["ds4macos"]))
targets.append(.target(name: "DS4Mac", dependencies: ["DualSenseCore"]))
targets.append(.executableTarget(name: "ds4probe", dependencies: ["DualSenseCore", "DS4Mac"]))
targets.append(.executableTarget(name: "ds4macos", dependencies: ["DualSenseCore", "DS4Mac"]))
#endif

let package = Package(
    name: "DS4MacOS",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets,
    swiftLanguageModes: [.v5]
)
