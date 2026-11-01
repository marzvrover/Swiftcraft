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

    func testDecodeHandshake() {
        var buffer = allocator.buffer(capacity: 0)
        let test = Handshake()
        test.version = 754
        test.port = 25564
        test.intention = 1
        test.address = "127.0.0.1"

        test.encode(buffer: &buffer)
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(inputOutputPairs: [
                (buffer, [test]),
            ]) {
                return PacketCodec(connection: ConnectionContext())
            }
        } catch {
            if !(error is PacketCodecError.Decode) {
                XCTFail("Unexpected Error: \(error)")
            }
        }
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
}
