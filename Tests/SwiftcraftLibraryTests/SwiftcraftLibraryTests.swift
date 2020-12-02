import XCTest
import class Foundation.Bundle
import NIO
@testable import SwiftcraftLibrary

final class SwiftcraftLibraryTests: XCTestCase {
    func testVarInt() throws {
        let allocator = ByteBufferAllocator()
        // [0xff, 0xff, 0xff, 0xff, 0x07] = 2147483647
        var buffer = allocator.buffer(capacity: 5)
        buffer.writeBytes([0xff, 0xff, 0xff, 0xff, 0x07])
        XCTAssertEqual(try! Int32(buffer: &buffer), Int32(2147483647))
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
    ]
}
