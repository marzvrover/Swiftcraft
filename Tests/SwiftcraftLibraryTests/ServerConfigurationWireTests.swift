import Foundation
import XCTest
import NIO
@testable import SwiftcraftLibrary

private enum ServerConfigurationWireTestSupport {
    static func makeChannel(
        configuration: ServerConfiguration
    ) -> EmbeddedChannel {
        let connection = ConnectionContext()
        return EmbeddedChannel(handlers: [
            ByteToMessageHandler(PacketCodec(connection: connection)),
            MessageToByteHandler(PacketCodec(connection: connection)),
            DisplayPacketHandler(
                connection: connection,
                configuration: configuration
            ),
        ])
    }

    static func sendHandshake(
        to channel: EmbeddedChannel,
        intention: UInt8
    ) throws {
        try channel.writeInbound(ByteBufferAllocator().buffer(bytes: [
            0x10, 0x00, 0xF2, 0x05, 0x09,
            0x6C, 0x6F, 0x63, 0x61, 0x6C,
            0x68, 0x6F, 0x73, 0x74,
            0x63, 0xDD, intention,
        ]))
    }

    static func readJSONPacket(
        from channel: EmbeddedChannel,
        expectedMessage: String
    ) throws -> [String: Any] {
        var response = try XCTUnwrap(
            channel.readOutbound(as: ByteBuffer.self),
            expectedMessage
        )
        let frameLength = try response.readVarInt()
        XCTAssertGreaterThan(frameLength, 0)
        XCTAssertEqual(Int(frameLength), response.readableBytes)
        XCTAssertEqual(try response.readVarInt(), 0x00)

        let json = try XCTUnwrap(response.readVarString())
        XCTAssertEqual(response.readableBytes, 0)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try XCTUnwrap(object as? [String: Any])
    }

    static func readJSONText(
        from channel: EmbeddedChannel,
        expectedMessage: String
    ) throws -> String {
        var response = try XCTUnwrap(
            channel.readOutbound(as: ByteBuffer.self),
            expectedMessage
        )
        let frameLength = try response.readVarInt()
        XCTAssertEqual(Int(frameLength), response.readableBytes)
        XCTAssertEqual(try response.readVarInt(), 0x00)
        let json = try XCTUnwrap(response.readVarString())
        XCTAssertEqual(response.readableBytes, 0)
        return json
    }

    static func makeConfiguration(motd: String) throws
        -> ServerConfiguration {
        try ServerConfiguration(
            fileValues: ["motd": motd],
            environment: [:]
        )
    }
}

final class ServerConfigurationWireTests: XCTestCase {
    func testStatusResponseWireUsesConfiguredProtocolAndSettings() throws {
        let configuration = try ServerConfiguration(
            fileValues: [
                "protocol_version": "754",
                "motd": "Configured MOTD",
                "max_players": "23",
            ],
            environment: [:]
        )
        let channel = ServerConfigurationWireTestSupport.makeChannel(
            configuration: configuration
        )
        try ServerConfigurationWireTestSupport.sendHandshake(
            to: channel,
            intention: 0x01
        )
        try channel.writeInbound(
            ByteBufferAllocator().buffer(bytes: [0x01, 0x00])
        )

        let root = try ServerConfigurationWireTestSupport.readJSONPacket(
            from: channel,
            expectedMessage: "Expected a Status Response"
        )
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

        XCTAssertTrue(try channel.readInbound(as: Packet.self) is Handshake)
        XCTAssertTrue(try channel.readInbound(as: Packet.self) is StatusRequest)
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
        let channel = ServerConfigurationWireTestSupport.makeChannel(
            configuration: configuration
        )
        try channel.connect(
            to: SocketAddress(ipAddress: "127.0.0.1", port: 25565)
        ).wait()
        try ServerConfigurationWireTestSupport.sendHandshake(
            to: channel,
            intention: 0x02
        )
        try channel.writeInbound(
            ByteBufferAllocator().buffer(bytes: [
                0x07, 0x00, 0x05,
                0x53, 0x74, 0x65, 0x76, 0x65,
            ])
        )
        channel.embeddedEventLoop.run()

        let reason = try ServerConfigurationWireTestSupport.readJSONPacket(
            from: channel,
            expectedMessage: "Expected a Login Disconnect"
        )
        XCTAssertEqual(reason["text"] as? String, "Configured rejection")
        XCTAssertFalse(channel.isActive)
        XCTAssertTrue(try channel.readInbound(as: Packet.self) is Handshake)
        XCTAssertTrue(
            try channel.finish(acceptAlreadyClosed: true).isClean
        )
    }

    func testMOTDAtStatusJSONLengthBoundaryIsAccepted() throws {
        let baseline = try ServerConfigurationWireTestSupport.makeConfiguration(
            motd: ""
        )
        let baselineLength = try StatusInfo(configuration: baseline)
            .json().utf16.count
        let motd = String(
            repeating: "x",
            count: Protocol754.WireLimits.stringMaximumCharacters
                - baselineLength
        )
        let configuration =
            try ServerConfigurationWireTestSupport.makeConfiguration(
                motd: motd
            )

        let channel = ServerConfigurationWireTestSupport.makeChannel(
            configuration: configuration
        )
        try ServerConfigurationWireTestSupport.sendHandshake(
            to: channel,
            intention: 0x01
        )
        try channel.writeInbound(
            ByteBufferAllocator().buffer(bytes: [0x01, 0x00])
        )
        let statusJSON = try ServerConfigurationWireTestSupport.readJSONText(
            from: channel,
            expectedMessage: "Expected a Status Response at the boundary"
        )
        XCTAssertEqual(
            statusJSON.utf16.count,
            Protocol754.WireLimits.stringMaximumCharacters
        )
        XCTAssertTrue(try channel.readInbound(as: Packet.self) is Handshake)
        XCTAssertTrue(try channel.readInbound(as: Packet.self) is StatusRequest)
        XCTAssertTrue(try channel.finish().isClean)
    }

    func testMOTDOverStatusJSONLengthBoundaryIsRejected() throws {
        let baseline = try ServerConfigurationWireTestSupport.makeConfiguration(
            motd: ""
        )
        let baselineLength = try StatusInfo(configuration: baseline)
            .json().utf16.count
        let motd = String(
            repeating: "x",
            count: Protocol754.WireLimits.stringMaximumCharacters
                - baselineLength + 1
        )

        XCTAssertThrowsError(
            try ServerConfigurationWireTestSupport.makeConfiguration(
                motd: motd
            )
        ) { error in
            XCTAssertEqual(
                error as? ServerConfigurationError,
                .invalidValue(key: "motd", value: motd)
            )
        }
    }

    func testMOTDJSONEscapingCanExceedLimitWhenRawTextFits() throws {
        let baseline = try ServerConfigurationWireTestSupport.makeConfiguration(
            motd: ""
        )
        let baselineLength = try StatusInfo(configuration: baseline)
            .json().utf16.count
        let quoteCount =
            Protocol754.WireLimits.stringMaximumCharacters - baselineLength
        let motd = String(repeating: "\"", count: quoteCount)
        XCTAssertLessThanOrEqual(
            baselineLength + motd.utf16.count,
            Protocol754.WireLimits.stringMaximumCharacters
        )

        XCTAssertThrowsError(
            try ServerConfigurationWireTestSupport.makeConfiguration(
                motd: motd
            )
        ) { error in
            XCTAssertEqual(
                error as? ServerConfigurationError,
                .invalidValue(key: "motd", value: motd)
            )
        }
    }
}
