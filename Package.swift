// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TypeLikeMe",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TypeLikeMe",
            path: "Sources/TypeLikeMe",
            swiftSettings: [.unsafeFlags(["-Osize"], .when(configuration: .release))],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-dead_strip"])]
        )
    ],
    swiftLanguageVersions: [.v5]
)
