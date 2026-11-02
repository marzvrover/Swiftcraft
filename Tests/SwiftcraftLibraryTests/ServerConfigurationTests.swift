import Foundation
import XCTest
@testable import SwiftcraftLibrary

final class ServerConfigurationTests: XCTestCase {
    private func writeProperties(_ contents: String) throws -> URL {
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

    private func removeProperties(_ file: URL) throws {
        try FileManager.default.removeItem(
            at: file.deletingLastPathComponent()
        )
    }

    func testLoadsFileHostAndProtocolAsTypedValues() throws {
        let file = try writeProperties(
            """
            server_ip="192.0.2.44"
            protocol_version=754
            """
        )
        defer { try? removeProperties(file) }

        let configuration = try ServerConfiguration.load(
            path: file.path,
            environment: [:]
        )

        XCTAssertEqual(configuration.host, "192.0.2.44")
        XCTAssertEqual(configuration.protocolVersion, .v754)
    }

    func testFileEnvironmentAndDefaultsPrecedence() throws {
        let file = try writeProperties(
            """
            server_ip="192.0.2.10"
            server_port=25565
            motd="From the file"
            max_players=12
            """
        )
        defer { try? removeProperties(file) }

        let configuration = try ServerConfiguration.load(
            path: file.path,
            environment: [
                "server_port": "25570",
                "motd": "From the environment",
            ]
        )

        XCTAssertEqual(configuration.host, "192.0.2.10")
        XCTAssertEqual(configuration.port, 25_570)
        XCTAssertEqual(configuration.protocolVersion, .v754)
        XCTAssertEqual(configuration.motd, "From the environment")
        XCTAssertEqual(configuration.maxPlayers, 12)
        XCTAssertEqual(
            configuration.loginRejectionMessage,
            ServerConfiguration.defaultLoginRejectionMessage
        )
    }

    func testOnlySupportedProtocolVersionIsAccepted() throws {
        let accepted = try ServerConfiguration(
            fileValues: ["protocol_version": "754"],
            environment: [:]
        )
        XCTAssertEqual(accepted.protocolVersion, .v754)

        XCTAssertThrowsError(
            try ServerConfiguration(
                fileValues: ["protocol_version": "755"],
                environment: [:]
            )
        ) { error in
            XCTAssertEqual(
                error as? ServerConfigurationError,
                .unsupportedProtocolVersion(755)
            )
        }

        XCTAssertThrowsError(
            try ServerConfiguration(
                fileValues: ["protocol_version": "not-a-number"],
                environment: [:]
            )
        ) { error in
            XCTAssertEqual(
                error as? ServerConfigurationError,
                .invalidValue(
                    key: "protocol_version",
                    value: "not-a-number"
                )
            )
        }
    }

    func testMissingFileUsesDefaultsAndEnvironment() throws {
        let missingPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing.properties")
            .path

        let configuration = try ServerConfiguration.load(
            path: missingPath,
            environment: ["server_ip": "127.0.0.2"]
        )

        XCTAssertEqual(configuration.host, "127.0.0.2")
        XCTAssertEqual(configuration.port, ServerConfiguration.defaultPort)
        XCTAssertEqual(
            configuration.protocolVersion,
            ServerConfiguration.defaultProtocolVersion
        )
        XCTAssertEqual(configuration.motd, ServerConfiguration.defaultMOTD)
        XCTAssertEqual(
            configuration.maxPlayers,
            ServerConfiguration.defaultMaxPlayers
        )
    }

    func testInvalidPortThrowsInsteadOfUsingDefault() throws {
        let file = try writeProperties("server_port=not-a-port\n")
        defer { try? removeProperties(file) }

        XCTAssertThrowsError(
            try ServerConfiguration.load(path: file.path, environment: [:])
        ) { error in
            XCTAssertEqual(
                error as? ServerConfigurationError,
                .invalidValue(key: "server_port", value: "not-a-port")
            )
        }
    }

    func testInvalidPlayerCountThrows() throws {
        let file = try writeProperties("max_players=-1\n")
        defer { try? removeProperties(file) }

        XCTAssertThrowsError(
            try ServerConfiguration.load(path: file.path, environment: [:])
        ) { error in
            XCTAssertEqual(
                error as? ServerConfigurationError,
                .invalidValue(key: "max_players", value: "-1")
            )
        }
    }

}
