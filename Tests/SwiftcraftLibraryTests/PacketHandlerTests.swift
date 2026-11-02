import XCTest
import NIO
@testable import SwiftcraftLibrary

private enum PacketHandlerTestSupport {
    static func makeConnectedLoginChannel() throws
        -> (ConnectionContext, EmbeddedChannel) {
        let configuration = try PacketCodecTestSupport
            .makeHandlerTestConfiguration()
        let (connection, channel) = PacketCodecTestSupport.makeChannel(
            configuration: configuration
        )
        try channel.connect(
            to: SocketAddress(ipAddress: "127.0.0.1", port: 25565)
        ).wait()
        try channel.writeInbound(
            ByteBufferAllocator().buffer(
                bytes: PacketCodecTestSupport.handshakeBytes(intention: 0x02)
            )
        )
        return (connection, channel)
    }

    static func sendLoginStart(to channel: EmbeddedChannel) throws {
        try channel.writeInbound(ByteBufferAllocator().buffer(bytes: [
            0x07, 0x00, 0x05,
            0x53, 0x74, 0x65, 0x76, 0x65,
        ]))
        channel.embeddedEventLoop.run()
    }
}

final class PacketHandlerTests: XCTestCase {
    func testStatusRequestProducesJSONResponse() throws {
        let configuration = try PacketCodecTestSupport
            .makeHandlerTestConfiguration()
        let (connection, channel) = PacketCodecTestSupport.makeChannel(
            configuration: configuration
        )
        try channel.writeInbound(
            ByteBufferAllocator().buffer(
                bytes: PacketCodecTestSupport.handshakeBytes()
            )
        )

        XCTAssertTrue(connection.get() == .status)
        XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self))
        try channel.writeInbound(
            ByteBufferAllocator().buffer(bytes: [0x01, 0x00])
        )
        let root = try PacketCodecTestSupport.readJSONPacket(
            from: channel,
            expectedMessage: "Expected a Status Response"
        )

        let version = try XCTUnwrap(root["version"] as? [String: Any])
        XCTAssertEqual(version["name"] as? String, "1.16.5")
        XCTAssertEqual(version["protocol"] as? Int, 754)
        let players = try XCTUnwrap(root["players"] as? [String: Any])
        XCTAssertEqual(players["max"] as? Int, 255)
        XCTAssertEqual(players["online"] as? Int, 0)
        let description = try XCTUnwrap(
            root["description"] as? [String: Any]
        )
        XCTAssertEqual(description["text"] as? String, "Swiftcraft v0")
    }

    func testStatusPingEchoesPayloadAndCloses() throws {
        for sendStatusRequest in [true, false] {
            let channel =
                try PacketCodecTestSupport.makeConnectedStatusChannel(
                    sendStatusRequest: sendStatusRequest
                )
            try PacketCodecTestSupport.assertPingEchoesPayloadAndCloses(
                on: channel,
                sendStatusRequest: sendStatusRequest
            )
        }
    }

    func testLoginStartProducesDisconnectAndCloses() throws {
        let (connection, channel) =
            try PacketHandlerTestSupport.makeConnectedLoginChannel()
        XCTAssertTrue(connection.get() == .login)
        XCTAssertTrue(try channel.readInbound(as: Packet.self) is Handshake)
        XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self))
        XCTAssertTrue(channel.isActive)

        try PacketHandlerTestSupport.sendLoginStart(to: channel)
        let reason = try PacketCodecTestSupport.readJSONPacket(
            from: channel,
            expectedMessage: "Expected a Login Disconnect"
        )

        XCTAssertEqual(
            reason["text"] as? String,
            "Swiftcraft gameplay is not implemented yet."
        )
        XCTAssertFalse(channel.isActive)
        XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self))
        XCTAssertNil(try channel.readInbound(as: Packet.self))
        XCTAssertTrue(
            try channel.finish(acceptAlreadyClosed: true).isClean
        )
    }

    func testMalformedInputClosesActiveChannel() throws {
        let configuration = try PacketCodecTestSupport
            .makeHandlerTestConfiguration()
        let (_, channel) = PacketCodecTestSupport.makeChannel(
            configuration: configuration
        )
        try channel.connect(
            to: SocketAddress(ipAddress: "127.0.0.1", port: 25565)
        ).wait()
        XCTAssertTrue(channel.isActive)

        try channel.writeInbound(ByteBufferAllocator().buffer(bytes: [0x01, 0x7F]))
        channel.embeddedEventLoop.run()

        XCTAssertFalse(channel.isActive)
        XCTAssertTrue(try channel.finish(acceptAlreadyClosed: true).isClean)
    }
}
