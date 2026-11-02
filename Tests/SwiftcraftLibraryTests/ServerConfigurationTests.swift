import Foundation
import XCTest
import NIO
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

    func testPortAndAdvertisedPlayerCountBoundaries() throws {
        let accepted = try ServerConfiguration(
            fileValues: [
                "server_port": "65535",
                "max_players": "0",
            ],
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
            XCTAssertThrowsError(
                try ServerConfiguration(
                    fileValues: ["server_port": invalidPort],
                    environment: [:]
                )
            ) { error in
                XCTAssertEqual(
                    error as? ServerConfigurationError,
                    .invalidValue(
                        key: "server_port",
                        value: invalidPort
                    )
                )
            }
        }

        XCTAssertThrowsError(
            try ServerConfiguration(
                fileValues: ["max_players": "2147483648"],
                environment: [:]
            )
        ) { error in
            XCTAssertEqual(
                error as? ServerConfigurationError,
                .invalidValue(
                    key: "max_players",
                    value: "2147483648"
                )
            )
        }
    }

    func testUnknownAndDuplicateFileKeysThrow() throws {
        let unknownFile = try writeProperties("max_player=12\n")
        defer { try? removeProperties(unknownFile) }
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

        let duplicateFile = try writeProperties(
            "motd=First\nmotd=Second\n"
        )
        defer { try? removeProperties(duplicateFile) }
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

    func testStatusResponseWireUsesConfiguredProtocolAndSettings() throws {
        let configuration = try ServerConfiguration(
            fileValues: [
                "protocol_version": "754",
                "motd": "Configured MOTD",
                "max_players": "23",
            ],
            environment: [:]
        )
        let connection = ConnectionContext()
        let channel = EmbeddedChannel(handlers: [
            ByteToMessageHandler(
                PacketCodec(connection: connection)
            ),
            MessageToByteHandler(
                PacketCodec(connection: connection)
            ),
            DisplayPacketHandler(
                connection: connection,
                configuration: configuration
            ),
        ])

        try channel.writeInbound(
            ByteBufferAllocator().buffer(bytes: [
                0x10, 0x00, 0xF2, 0x05, 0x09,
                0x6C, 0x6F, 0x63, 0x61, 0x6C,
                0x68, 0x6F, 0x73, 0x74,
                0x63, 0xDD, 0x01,
            ])
        )
        try channel.writeInbound(
            ByteBufferAllocator().buffer(bytes: [0x01, 0x00])
        )

        var response = try XCTUnwrap(
            channel.readOutbound(as: ByteBuffer.self),
            "Expected a Status Response"
        )
        let frameLength = try response.readVarInt()
        XCTAssertGreaterThan(frameLength, 0)
        XCTAssertEqual(Int(frameLength), response.readableBytes)

        let packetID = try response.readVarInt()
        XCTAssertEqual(packetID, 0x00)

        let json = try XCTUnwrap(response.readVarString())
        XCTAssertEqual(response.readableBytes, 0)

        let object = try JSONSerialization.jsonObject(
            with: Data(json.utf8)
        )
        let root = try XCTUnwrap(object as? [String: Any])
        let version = try XCTUnwrap(root["version"] as? [String: Any])
        let players = try XCTUnwrap(root["players"] as? [String: Any])
        let description = try XCTUnwrap(
            root["description"] as? [String: Any]
        )

        XCTAssertEqual(version["name"] as? String, "1.16.5")
        XCTAssertEqual(version["protocol"] as? Int, 754)
        XCTAssertEqual(players["max"] as? Int, 23)
        XCTAssertEqual(players["online"] as? Int, 0)
        XCTAssertEqual(description["text"] as? String, "Configured MOTD")

        let handshake = try XCTUnwrap(
            channel.readInbound(as: Packet.self) as? Handshake
        )
        XCTAssertEqual(handshake.id, 0x00)
        let statusRequest = try XCTUnwrap(
            channel.readInbound(as: Packet.self) as? StatusRequest
        )
        XCTAssertEqual(statusRequest.id, 0x00)
        XCTAssertTrue(try channel.finish().isClean)
    }

    func testLoginRejectionMessageReachesDisconnectWirePacket() throws {
        let configuration = try ServerConfiguration(
            fileValues: [
                "protocol_version": "754",
                "login_rejection_message": "Configured rejection",
            ],
            environment: [:]
        )
        let connection = ConnectionContext()
        let channel = EmbeddedChannel(handlers: [
            ByteToMessageHandler(
                PacketCodec(connection: connection)
            ),
            MessageToByteHandler(
                PacketCodec(connection: connection)
            ),
            DisplayPacketHandler(
                connection: connection,
                configuration: configuration
            ),
        ])
        try channel.connect(
            to: SocketAddress(ipAddress: "127.0.0.1", port: 25565)
        ).wait()

        try channel.writeInbound(
            ByteBufferAllocator().buffer(bytes: [
                0x10, 0x00, 0xF2, 0x05, 0x09,
                0x6C, 0x6F, 0x63, 0x61, 0x6C,
                0x68, 0x6F, 0x73, 0x74,
                0x63, 0xDD, 0x02,
            ])
        )
        try channel.writeInbound(
            ByteBufferAllocator().buffer(bytes: [
                0x07, 0x00, 0x05,
                0x53, 0x74, 0x65, 0x76, 0x65,
            ])
        )
        channel.embeddedEventLoop.run()

        var response = try XCTUnwrap(
            channel.readOutbound(as: ByteBuffer.self),
            "Expected a Login Disconnect"
        )
        let frameLength = try response.readVarInt()
        XCTAssertGreaterThan(frameLength, 0)
        XCTAssertEqual(Int(frameLength), response.readableBytes)

        let packetID = try response.readVarInt()
        XCTAssertEqual(packetID, 0x00)

        let json = try XCTUnwrap(response.readVarString())
        XCTAssertEqual(response.readableBytes, 0)

        let object = try JSONSerialization.jsonObject(
            with: Data(json.utf8)
        )
        let reason = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(reason["text"] as? String, "Configured rejection")
        XCTAssertFalse(channel.isActive)

        let handshake = try XCTUnwrap(
            channel.readInbound(as: Packet.self) as? Handshake
        )
        XCTAssertEqual(handshake.id, 0x00)
        XCTAssertTrue(
            try channel.finish(acceptAlreadyClosed: true).isClean
        )
    }
}
