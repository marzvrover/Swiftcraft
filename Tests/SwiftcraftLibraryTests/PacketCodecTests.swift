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
}
