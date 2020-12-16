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

    func testDecodeHandshake() {
        var buffer = allocator.buffer(capacity: 0)
        let test = Handshake()
        test.version = 724
        test.port = 25564
        test.intention = 1
        test.address = "127.0.0.1"

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
        ("testDecodeHandshake", testDecodeHandshake),
    ]
}
