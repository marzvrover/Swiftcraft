// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),

        .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.23.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Swiftcraft",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIO", package: "swift-nio"),
                "Rainbow",
                "SwiftcraftLibrary",
            ]
        ),
        .target(
            name: "SwiftcraftLibrary",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIO", package: "swift-nio"),
                "Rainbow",
            ]
        ),
        .testTarget(
            name: "SwiftcraftLibraryTests",
            dependencies: [
                "SwiftcraftLibrary",
                .product(name: "NIO", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "SwiftcraftTests",
            dependencies: [
                "Swiftcraft",
                .product(name: "NIO", package: "swift-nio"),
            ]
        ),
    ]
)
