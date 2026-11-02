import XCTest
import class Foundation.Bundle
import NIO
import NIOTestUtils
@testable import SwiftcraftLibrary

enum PacketCodecTestSupport {
    static func makeChannel(
        configuration: ServerConfiguration
    ) -> (ConnectionContext, EmbeddedChannel) {
        let connection = ConnectionContext()
        let channel = EmbeddedChannel(handlers: [
            ByteToMessageHandler(PacketCodec(connection: connection)),
            MessageToByteHandler(PacketCodec(connection: connection)),
            DisplayPacketHandler(
                connection: connection,
                configuration: configuration
            ),
        ])
        return (connection, channel)
    }

    static func handshakeBytes(intention: UInt8 = 0x01) -> [UInt8] {
        [
            0x10, 0x00, 0xF2, 0x05, 0x09,
            0x6C, 0x6F, 0x63, 0x61, 0x6C,
            0x68, 0x6F, 0x73, 0x74,
            0x63, 0xDD, intention,
        ]
    }

    static func handshakeRequestBytes() -> [UInt8] {
        [
            0x10,
            0x00,
            0xF2, 0x05,
            0x09,
            0x6C, 0x6F, 0x63,
            0x61, 0x6C, 0x68,
            0x6F, 0x73, 0x74,
            0x63, 0xDD,
            0x01,
        ]
    }

    static func decodeHandshake(
        _ bytes: [UInt8],
        at split: Int,
        allocator: ByteBufferAllocator
    ) throws -> Handshake {
        let connection = ConnectionContext()
        connection.set(.handshaking)
        let channel = EmbeddedChannel(
            handler: ByteToMessageHandler(PacketCodec(connection: connection))
        )
        try channel.writeInbound(
            allocator.buffer(bytes: Array(bytes.prefix(split)))
        )
        try channel.writeInbound(
            allocator.buffer(bytes: Array(bytes.dropFirst(split)))
        )
        let packet = try channel.readInbound(as: Packet.self)
        let handshake = try XCTUnwrap(
            packet as? Handshake,
            "Expected a handshake at split \(split)"
        )
        XCTAssertNil(
            try channel.readInbound(as: Packet.self),
            "Unexpected extra packet at split \(split)"
        )
        XCTAssertTrue(
            try channel.finish().isClean,
            "Leftover data at split \(split)"
        )
        return handshake
    }

    static func makeHandlerTestConfiguration(
        motd: String = "Swiftcraft v0",
        maxPlayers: Int = 255
    ) throws -> ServerConfiguration {
        try ServerConfiguration(
            fileValues: [
                "motd": motd,
                "max_players": String(maxPlayers),
            ],
            environment: ["protocol_version": "754"]
        )
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

    static func makeConnectedStatusChannel(
        sendStatusRequest: Bool
    ) throws -> EmbeddedChannel {
        let configuration = try ServerConfiguration(
            fileValues: [:],
            environment: ["protocol_version": "754"]
        )
        let (connection, channel) = makeChannel(configuration: configuration)
        try channel.connect(
            to: SocketAddress(ipAddress: "127.0.0.1", port: 25565)
        ).wait()
        XCTAssertTrue(channel.isActive)

        try channel.writeInbound(
            ByteBufferAllocator().buffer(bytes: handshakeBytes())
        )
        XCTAssertTrue(connection.get() == .status)
        XCTAssertTrue(try channel.readInbound(as: Packet.self) is Handshake)
        XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self))

        if sendStatusRequest {
            try channel.writeInbound(
                ByteBufferAllocator().buffer(bytes: [0x01, 0x00])
            )
            _ = try XCTUnwrap(
                channel.readOutbound(as: ByteBuffer.self),
                "Expected a Status Response before Pong"
            )
            XCTAssertTrue(
                try channel.readInbound(as: Packet.self) is StatusRequest
            )
            channel.embeddedEventLoop.run()
            XCTAssertTrue(channel.isActive)
        }

        return channel
    }

    static func assertPingEchoesPayloadAndCloses(
        on channel: EmbeddedChannel,
        sendStatusRequest: Bool
    ) throws {
        let pingBytes: [UInt8] = [
            0x09, 0x01, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x2A,
        ]
        try channel.writeInbound(ByteBufferAllocator().buffer(bytes: pingBytes))
        channel.embeddedEventLoop.run()

        let pong = try XCTUnwrap(
            channel.readOutbound(as: ByteBuffer.self),
            "Expected Pong; sendStatusRequest = \(sendStatusRequest)"
        )
        XCTAssertEqual(
            Array(pong.readableBytesView),
            pingBytes,
            "Pong must echo the exact payload"
        )
        XCTAssertFalse(
            channel.isActive,
            "The connection should close after writing Pong"
        )
        XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self))
        XCTAssertNil(try channel.readInbound(as: Packet.self))
        XCTAssertTrue(
            try channel.finish(acceptAlreadyClosed: true).isClean
        )
    }
}

final class PacketCodecTests: XCTestCase {
    let allocator = ByteBufferAllocator()

    func testConnectionStateIsIndependent() {
        let first = ConnectionContext()
        let sameFirst = first
        let second = ConnectionContext()

        sameFirst.set(.status)

        XCTAssertTrue(first.get() == .status)
        XCTAssertTrue(second.get() == .handshaking)
    }

    func testDecodeHandshake() throws {
        var buffer = allocator.buffer(capacity: 0)
        let handshake = Handshake()
        handshake.version = 754
        handshake.port = 25564
        handshake.intention = 1
        handshake.address = "127.0.0.1"

        handshake.encode(buffer: &buffer)

        try ByteToMessageDecoderVerifier.verifyDecoder(
            inputOutputPairs: [
                (buffer, [handshake]),
            ]
        ) {
            PacketCodec(connection: ConnectionContext())
        }
    }

    func testEncodeStatusRequestHasCorrectWireBytes() {
        var buffer = allocator.buffer(capacity: 0)

        StatusRequest().encode(buffer: &buffer)

        XCTAssertEqual(Array(buffer.readableBytesView), [0x01, 0x00])
    }

    func testEncodeStatusRequestAppendsToExistingBuffer() {
        var buffer = allocator.buffer(capacity: 0)
        let request = StatusRequest()

        request.encode(buffer: &buffer)
        request.encode(buffer: &buffer)

        XCTAssertEqual(
            Array(buffer.readableBytesView),
            [0x01, 0x00, 0x01, 0x00]
        )
    }

    func testHandshakeRequestAtEverySplit() throws {
        let bytes = PacketCodecTestSupport.handshakeRequestBytes()
        for split in 0...bytes.count {
            let handshake = try PacketCodecTestSupport.decodeHandshake(
                bytes,
                at: split,
                allocator: allocator
            )
            XCTAssertEqual(handshake.id, 0x00)
            XCTAssertEqual(handshake.version, 754)
            XCTAssertEqual(handshake.address, "localhost")
            XCTAssertEqual(handshake.port, 25565)
            XCTAssertEqual(handshake.intention, 1)
        }
    }

    func testStatusRequestAtEverySplit() throws {
        let bytes: [UInt8] = [0x01, 0x00]

        for split in 0...bytes.count {
            let connection = ConnectionContext()
            connection.set(.status)

            let channel = EmbeddedChannel(
              handler: ByteToMessageHandler(
                  PacketCodec(connection: connection)
              )
            )

            try channel.writeInbound(
                allocator.buffer(bytes: Array(bytes.prefix(split)))
            )
            try channel.writeInbound(
                allocator.buffer(bytes: Array(bytes.dropFirst(split)))
            )

            let decoded = try channel.readInbound(as: Packet.self)
            XCTAssertTrue(decoded is StatusRequest)
            XCTAssertNil(try channel.readInbound(as: Packet.self))
            XCTAssertTrue(try channel.finish().isClean)
        }
    }

}
