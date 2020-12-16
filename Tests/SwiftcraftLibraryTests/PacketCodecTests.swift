import XCTest
import class Foundation.Bundle
import NIO
import NIOTestUtils
@testable import SwiftcraftLibrary

final class PacketCodecTests: XCTestCase {
    class TestPacket: Packet {
        init(definition: Definition) {
            super.init(
                id: Int32.min,
                definition: definition,
                data: [:]
                )
        }
        init(definition: Definition, data: [String:Any]) {
            super.init(
                id: Int32.min,
                definition: definition,
                data: data
                )
        }
    }

    let allocator = ByteBufferAllocator()

    func testPacketDecoder() {
        var buffer = allocator.buffer(capacity: 0)
        let test = TestPacket(definition: [
            (name: "test", type: .varInt, args: nil),
        ],
        data: [
            "test": Int32(47),
        ])
        test.encode(buffer: &buffer)
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(inputOutputPairs: [
                (buffer, [test])
            ]) {
                return PacketDecoder()
            }
        } catch {
            XCTFail("Unexpected Error: \(error)")
        }
    }

    static var allTests = [
        ("testPacketDecoder", testPacketDecoder),
    ]
}
