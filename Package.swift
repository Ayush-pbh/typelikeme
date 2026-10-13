// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TypeLikeMe",
    platforms: [.macOS(.v14)],
    dependencies: [
        // On-device Parakeet speech recognition (Core ML, runs on the Neural Engine).
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.12.4"),
    ],
    targets: [
        .executableTarget(
            name: "TypeLikeMe",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            path: "Sources/TypeLikeMe",
            swiftSettings: [.unsafeFlags(["-Osize"], .when(configuration: .release))],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-dead_strip"])]
        )
    ],
    swiftLanguageVersions: [.v5]
)
