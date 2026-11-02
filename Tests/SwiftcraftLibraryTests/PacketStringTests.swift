import XCTest
import NIO
@testable import SwiftcraftLibrary

private enum PacketStringTestSupport {
    static func decodeHandshake(address: String) throws -> Handshake {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeVarInt(754)
        buffer.writeVarString(address)
        buffer.writeInteger(UInt16(25565))
        buffer.writeVarInt(1)
        var packet = Handshake()
        try packet.decode(buffer: &buffer)
        XCTAssertEqual(buffer.readableBytes, 0)
        return packet
    }

    static func assertRejected(address: String, file: StaticString = #filePath,
                               line: UInt = #line) {
        XCTAssertThrowsError(
            try decodeHandshake(address: address),
            file: file,
            line: line
        ) { error in
            guard let fieldError = error as? PacketFieldError else {
                XCTFail("Expected PacketFieldError", file: file, line: line)
                return
            }
            switch fieldError {
            case .invalidStringLength:
                break
            case .missing:
                XCTFail("Expected invalid string length", file: file, line: line)
            }
        }
    }
}

final class PacketStringTests: XCTestCase {
    func testVarStringDecodesMultibyteCharactersWithinLimit() throws {
        let expected = String(repeating: "é", count: 128)
        let packet = try PacketStringTestSupport.decodeHandshake(
            address: expected
        )
        XCTAssertEqual(packet.address, expected)
    }

    func testVarStringRejectsMoreThanCharacterLimit() {
        PacketStringTestSupport.assertRejected(
            address: String(repeating: "a", count: 256)
        )
    }

    func testHandshakeAccepts255UTF16UnitsOfSupplementaryUnicode() throws {
        let address = String(repeating: "😀", count: 127) + "a"
        XCTAssertEqual(address.utf16.count, 255)
        let packet = try PacketStringTestSupport.decodeHandshake(address: address)
        XCTAssertEqual(packet.address, address)
    }

    func testHandshakeRejects256UTF16UnitsOfSupplementaryUnicode() {
        let address = String(repeating: "😀", count: 128)
        XCTAssertEqual(address.utf16.count, 256)
        PacketStringTestSupport.assertRejected(address: address)
    }
}
