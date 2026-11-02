import Foundation
import XCTest
@testable import SwiftcraftLibrary

private enum ServerConfigurationValidationTestSupport {
    static func assertInvalid(
        _ fileValues: [String: String],
        equals expected: ServerConfigurationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try ServerConfiguration(fileValues: fileValues, environment: [:]),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? ServerConfigurationError,
                expected,
                file: file,
                line: line
            )
        }
    }

    static func writeProperties(_ contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let file = directory.appendingPathComponent("server.properties")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    static func removeProperties(_ file: URL) throws {
        try FileManager.default.removeItem(
            at: file.deletingLastPathComponent()
        )
    }
}

final class ServerConfigurationValidationTests: XCTestCase {
    func testPortAndAdvertisedPlayerCountBoundaries() throws {
        let accepted = try ServerConfiguration(
            fileValues: ["server_port": "65535", "max_players": "0"],
            environment: [:]
        )
        XCTAssertEqual(accepted.port, 65_535)
        XCTAssertEqual(accepted.maxPlayers, 0)

        let maximumPlayerCount = try ServerConfiguration(
            fileValues: ["max_players": String(Int32.max)],
            environment: [:]
        )
        XCTAssertEqual(maximumPlayerCount.maxPlayers, Int(Int32.max))

        for invalidPort in ["0", "65536"] {
            ServerConfigurationValidationTestSupport.assertInvalid(
                ["server_port": invalidPort],
                equals: .invalidValue(key: "server_port", value: invalidPort)
            )
        }
        ServerConfigurationValidationTestSupport.assertInvalid(
            ["max_players": "2147483648"],
            equals: .invalidValue(
                key: "max_players",
                value: "2147483648"
            )
        )
    }

    func testUnknownAndDuplicateFileKeysThrow() throws {
        let unknownFile = try ServerConfigurationValidationTestSupport
            .writeProperties("max_player=12\n")
        defer {
            try? ServerConfigurationValidationTestSupport.removeProperties(
                unknownFile
            )
        }
        XCTAssertThrowsError(
            try ServerConfiguration.load(
                path: unknownFile.path,
                environment: [:]
            )
        ) { error in
            XCTAssertEqual(
                error as? ServerConfigurationError,
                .unknownKey("max_player")
            )
        }

        let duplicateFile = try ServerConfigurationValidationTestSupport
            .writeProperties("motd=First\nmotd=Second\n")
        defer {
            try? ServerConfigurationValidationTestSupport.removeProperties(
                duplicateFile
            )
        }
        XCTAssertThrowsError(
            try ServerConfiguration.load(
                path: duplicateFile.path,
                environment: [:]
            )
        ) { error in
            XCTAssertEqual(
                error as? ServerConfigurationError,
                .duplicateKey("motd")
            )
        }
    }

    func testProtocol754ReleaseMetadataIsSeparateFromImplementationTarget() {
        let protocolVersion = Protocol754.v754

        XCTAssertEqual(
            protocolVersion.minimumMinecraftVersion,
            MinecraftVersion(major: 1, minor: 16, patch: 4)
        )
        XCTAssertEqual(
            protocolVersion.maximumMinecraftVersion,
            MinecraftVersion(major: 1, minor: 16, patch: 5)
        )
        XCTAssertEqual(protocolVersion.implementationVersionName, "1.16.5")
    }
}
