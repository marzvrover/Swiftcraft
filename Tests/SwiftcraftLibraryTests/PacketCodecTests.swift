import XCTest
import class Foundation.Bundle
import NIO
import NIOTestUtils
@testable import SwiftcraftLibrary

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
        let bytes: [UInt8] = [
            0x10,                   // Frame length: 16 bytes
            0x00,                   // Handshake packet ID
            0xF2, 0x05,             // Protocol version: 754
            0x09,                   // Address length: 9 bytes
            0x6C, 0x6F, 0x63,       // "loc"
            0x61, 0x6C, 0x68,       // "alh"
            0x6F, 0x73, 0x74,       // "ost"
            0x63, 0xDD,             // Port: 25565
            0x01,                   // Intention: status
        ]

        for split in 0...bytes.count {
            let connection = ConnectionContext()
            connection.set(.handshaking)

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

            let packet = try channel.readInbound(as: Packet.self)
            let handshake = try XCTUnwrap(
                packet as? Handshake,
                "Expected a handshake at split \(split)"
            )

            XCTAssertEqual(handshake.id, 0x00)
            XCTAssertEqual(handshake.version, 754)
            XCTAssertEqual(handshake.address, "localhost")
            XCTAssertEqual(handshake.port, 25565)
            XCTAssertEqual(handshake.intention, 1)

            XCTAssertNil(
                try channel.readInbound(as: Packet.self),
                "Unexpected extra packet at split \(split)"
            )
            XCTAssertTrue(
                try channel.finish().isClean,
                "Leftover data at split \(split)"
            )
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

    func testStatusRequestProducesJSONResponse() throws {
        let connection = ConnectionContext()

        let channel = EmbeddedChannel(handlers: [
            ByteToMessageHandler(
                PacketCodec(connection: connection)
            ),
            MessageToByteHandler(
                PacketCodec(connection: connection)
            ),
            DisplayPacketHandler(connection: connection),
        ])

        let handshakeBytes: [UInt8] = [
            0x10,                   // Frame length
            0x00,                   // Handshake ID
            0xF2, 0x05,             // Protocol version: 754
            0x09,                   // Address length
            0x6C, 0x6F, 0x63,
            0x61, 0x6C, 0x68,
            0x6F, 0x73, 0x74,       // "localhost"
            0x63, 0xDD,             // Port: 25565
            0x01,                   // Intention: status
        ]

        try channel.writeInbound(
            allocator.buffer(bytes: handshakeBytes)
        )

        XCTAssertTrue(connection.get() == .status)

        // The handshake itself should not produce a response.
        XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self))

        try channel.writeInbound(
            allocator.buffer(bytes: [0x01, 0x00])
        )

        // Read the bytes that would be sent to the Minecraft client.
        var response = try XCTUnwrap(
            channel.readOutbound(as: ByteBuffer.self),
            "Expected a Status Response"
        )

        let frameLength = try response.readVarInt()

        // After reading the prefix, all remaining bytes belong to this frame.
        XCTAssertGreaterThan(frameLength, 0)
        XCTAssertEqual(Int(frameLength), response.readableBytes)

        let packetID = try response.readVarInt()
        XCTAssertEqual(packetID, 0x00)

        // The response body is one Minecraft String containing JSON.
        let json = try XCTUnwrap(response.readVarString())
        XCTAssertEqual(response.readableBytes, 0)

        let object = try JSONSerialization.jsonObject(
            with: Data(json.utf8)
        )
        let root = try XCTUnwrap(object as? [String: Any])

        let version = try XCTUnwrap(
            root["version"] as? [String: Any]
        )
        XCTAssertEqual(version["name"] as? String, "1.16.5")
        XCTAssertEqual(version["protocol"] as? Int, 754)

        let players = try XCTUnwrap(
            root["players"] as? [String: Any]
        )
        XCTAssertEqual(players["max"] as? Int, 255)
        XCTAssertEqual(players["online"] as? Int, 0)

        let description = try XCTUnwrap(
            root["description"] as? [String: Any]
        )
        XCTAssertEqual(
            description["text"] as? String,
            "Swiftcraft v0"
        )
    }

    func testStatusPingEchoesPayloadAndCloses() throws {
        let handshakeBytes: [UInt8] = [
            0x10, 0x00, 0xF2, 0x05, 0x09,
            0x6C, 0x6F, 0x63, 0x61, 0x6C,
            0x68, 0x6F, 0x73, 0x74,
            0x63, 0xDD, 0x01,
        ]

        let pingBytes: [UInt8] = [
            0x09,                   // Frame length: ID + 8-byte payload
            0x01,                   // Ping ID
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x2A, // Payload: 42
        ]

        for sendStatusRequest in [true, false] {
            let connection = ConnectionContext()

            let channel = EmbeddedChannel(handlers: [
                ByteToMessageHandler(
                    PacketCodec(connection: connection)
                ),
                MessageToByteHandler(
                    PacketCodec(connection: connection)
                ),
                DisplayPacketHandler(connection: connection),
            ])

            // Activate the simulated connection; no real socket is opened.
            try channel.connect(
                to: SocketAddress(ipAddress: "127.0.0.1", port: 25565)
            ).wait()

            XCTAssertTrue(channel.isActive)

            try channel.writeInbound(
                allocator.buffer(bytes: handshakeBytes)
            )

            XCTAssertTrue(connection.get() == .status)

            let handshake = try channel.readInbound(as: Packet.self)
            XCTAssertTrue(handshake is Handshake)
            XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self))

            if sendStatusRequest {
                try channel.writeInbound(
                    allocator.buffer(bytes: [0x01, 0x00])
                )

                // Consume the JSON response before checking the Pong.
                _ = try XCTUnwrap(
                    channel.readOutbound(as: ByteBuffer.self),
                    "Expected a Status Response before Pong"
                )

                let request = try channel.readInbound(as: Packet.self)
                XCTAssertTrue(request is StatusRequest)

                // Sending the status information should not close the channel.
                channel.embeddedEventLoop.run()
                XCTAssertTrue(channel.isActive)
            }

            try channel.writeInbound(
                allocator.buffer(bytes: pingBytes)
            )

            // Run callbacks scheduled by the reply's write promise.
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

            // The Ping branch returns without forwarding the Ping downstream.
            XCTAssertNil(try channel.readInbound(as: Packet.self))

            XCTAssertTrue(
                try channel.finish(acceptAlreadyClosed: true).isClean
            )
        }
    }

    func testLoginStartProducesDisconnectAndCloses() throws {
        let connection = ConnectionContext()

        let channel = EmbeddedChannel(handlers: [
            ByteToMessageHandler(
                PacketCodec(connection: connection)
            ),
            MessageToByteHandler(
                PacketCodec(connection: connection)
            ),
            DisplayPacketHandler(connection: connection),
        ])

        try channel.connect(
            to: SocketAddress(ipAddress: "127.0.0.1", port: 25565)
        ).wait()

        // Protocol 754 handshake with intention 2: login.
        let handshakeBytes: [UInt8] = [
            0x10, 0x00, 0xF2, 0x05, 0x09,
            0x6C, 0x6F, 0x63, 0x61, 0x6C,
            0x68, 0x6F, 0x73, 0x74,
            0x63, 0xDD, 0x02,
        ]

        try channel.writeInbound(
            allocator.buffer(bytes: handshakeBytes)
        )

        XCTAssertTrue(connection.get() == .login)

        let handshake = try channel.readInbound(as: Packet.self)
        XCTAssertTrue(handshake is Handshake)

        XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self))
        XCTAssertTrue(channel.isActive)

        // Login Start: packet ID 0, username "Steve".
        let loginStartBytes: [UInt8] = [
            0x07,                   // Frame length: 1 + 1 + 5
            0x00,                   // Login Start ID
            0x05,                   // Username byte length
            0x53, 0x74, 0x65, 0x76, 0x65,
        ]

        try channel.writeInbound(
            allocator.buffer(bytes: loginStartBytes)
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

        XCTAssertEqual(
            reason["text"] as? String,
            "Swiftcraft gameplay is not implemented yet."
        )

        XCTAssertFalse(
            channel.isActive,
            "The connection should close after sending the rejection"
        )

        XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self))

        // The Login Start branch returns without forwarding the packet.
        XCTAssertNil(try channel.readInbound(as: Packet.self))

        XCTAssertTrue(
            try channel.finish(acceptAlreadyClosed: true).isClean
        )
    }
}
