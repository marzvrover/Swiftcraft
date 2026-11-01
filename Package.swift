// swift-tools-version:6.2
import PackageDescription
let package = Package(
    name: "Swiftcraft",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "Swiftcraft", targets: ["Swiftcraft"]),
        .library(name: "SwiftcraftLibrary", targets: ["SwiftcraftLibrary"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftpackages/DotEnv.git", from: "3.0.1"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.2.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.104.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.16.2"),
    ],
    targets: [
        .executableTarget(
            name: "Swiftcraft",
            dependencies: [
                "SwiftcraftLibrary",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Rainbow", package: "Rainbow"),
            ]
        ),
        .target(
            name: "SwiftcraftLibrary",
            dependencies: [
                .product(name: "DotEnv", package: "DotEnv"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Rainbow", package: "Rainbow"),
            ]
        ),
        .testTarget(
            name: "SwiftcraftLibraryTests",
            dependencies: [
                "SwiftcraftLibrary",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "SwiftcraftTests",
            dependencies: [
                "Swiftcraft",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
