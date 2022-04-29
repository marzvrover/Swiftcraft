// swift-tools-version:5.3
import PackageDescription
let package = Package(
    name: "Swiftcraft",
    platforms: [
        .macOS(.v10_10),
    ],
    products: [
        .executable(name: "Swiftcraft", targets: ["Swiftcraft"]),
        .library(name: "SwiftcraftLibrary", targets: ["SwiftcraftLibrary"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftpackages/DotEnv.git", from: "3.0.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.23.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
    ],
    targets: [
        .target(
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
    ]
)
