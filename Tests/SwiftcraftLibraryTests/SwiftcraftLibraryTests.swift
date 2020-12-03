import XCTest
import class Foundation.Bundle
import NIO
@testable import SwiftcraftLibrary

final class SwiftcraftLibraryTests: XCTestCase {
    let allocator = ByteBufferAllocator()

    let varIntData: [(bytes: [Byte], value: Int32)] = [
        (bytes: [0x00], value: 0),
        (bytes: [0x01], value: 1),
        (bytes: [0x02], value: 2),
        (bytes: [0x7f], value: 127),
        (bytes: [0x80, 0x01], value: 128),
        (bytes: [0xff, 0x01], value: 255),
        (bytes: [0xff, 0xff, 0xff, 0xff, 0x07], value: 2147483647),
        (bytes: [0xff, 0xff, 0xff, 0xff, 0x0f], value: -1),
        (bytes: [0x80, 0x80, 0x80, 0x80, 0x08], value: -2147483648),
        // current Minecraft protocol
        (bytes: [Byte(242), Byte(5)], value: 754),
    ]

    let varLongData: [(bytes: [Byte], value: Int64)] = [
        (bytes: [0x00], value: 0),
        (bytes: [0x01], value: 1),
        (bytes: [0x02], value: 2),
        (bytes: [0x7f], value: 127),
        (bytes: [0x80, 0x01], value: 128),
        (bytes: [0xff, 0x01], value: 255),
        (bytes: [0xff, 0xff, 0xff, 0xff, 0x07], value: 2147483647),
        (bytes: [0xff, 0xff, 0xff, 0xff, 0x0f], value: 4294967295),
        (bytes: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f], value: 9223372036854775807),
        (bytes: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01], value: -1),
        (bytes: [0x80, 0x80, 0x80, 0x80, 0xf8, 0xff, 0xff, 0xff, 0xff, 0x01], value: -2147483648),
        (bytes: [0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01], value: -9223372036854775808),
        // current Minecraft protocol
        (bytes: [Byte(242), Byte(5)], value: 754),
    ]
    
    func testVarInt() throws {
        for varInt in varIntData {
            var buffer = allocator.buffer(capacity: varInt.bytes.count)
            buffer.writeBytes(varInt.bytes)

            let output = try! buffer.readVarInt()
            XCTAssertEqual(output, Int32(varInt.value))

            buffer.writeVarInt(output)
            XCTAssertEqual(buffer.readBytes(length: varInt.bytes.count), varInt.bytes)
        }
    }
    
    func testVarLong() throws {
        for varLong in varLongData {
            var buffer = allocator.buffer(capacity: varLong.bytes.count)
            buffer.writeBytes(varLong.bytes)

            let output = try! buffer.readVarLong()
            XCTAssertEqual(output, Int64(varLong.value))

            buffer.writeVarLong(output)
            XCTAssertEqual(buffer.readBytes(length: varLong.bytes.count), varLong.bytes)
        }
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
      #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
      #else
        return Bundle.main.bundleURL
      #endif
    }

    static var allTests = [
        ("testVarInt", testVarInt),
        ("testVarLong", testVarLong),
    ]
}
