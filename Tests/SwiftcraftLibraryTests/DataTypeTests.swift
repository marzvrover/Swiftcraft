import XCTest
import class Foundation.Bundle
import NIO
@testable import SwiftcraftLibrary

struct TestPacket: Packet {
    var data: [String : Any] = [:]

    var definition: [(name: String, type: PacketData, args: [String : Any]?)]

    var id: Int32 = Int32.min
}

final class DataTypeTests: XCTestCase {
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

    func testBoolean() {
        var buffer = allocator.buffer(bytes: [0x01, 0x00])
        var packet = TestPacket(
            definition: [
                (name: "bool_true",
                 type: .boolean,
                 args: nil),
                (name: "bool_false",
                 type: .boolean,
                 args: nil),
            ])
        try! packet.decode(buffer: &buffer)

        XCTAssertTrue(packet.data["bool_true"] as! Bool)
        XCTAssertFalse(packet.data["bool_false"] as! Bool)
    }

    func testByte() {
        numberTestHelper(Int8.self, packetType: .byte)
    }

    func testUnsignedByte() {
        numberTestHelper(UInt8.self, packetType: .unsignedByte)
    }

    func testByteArray() {
        for (bytes, _) in varLongData {
            var buffer = allocator.buffer(bytes: bytes)
            var packet = TestPacket(definition: [(name: "bytes",
                                                  type: .byteArray,
                                                  args: ["length": bytes.count])])
            try! packet.decode(buffer: &buffer)
            XCTAssertEqual(packet.data["bytes"] as! [UInt8], bytes)
        }
    }

    func testShort() {
        numberTestHelper(Int16.self, packetType: .short)
    }

    func testUnsignedShort() {
        numberTestHelper(UInt16.self, packetType: .unsignedShort)
    }

    func testInt() {
        numberTestHelper(Int32.self, packetType: .int)
    }

    func testUnsignedInt() {
        numberTestHelper(UInt32.self, packetType: .unsignedInt)
    }

    func testLong() {
        numberTestHelper(Int64.self, packetType: .long)
    }

    func testUnsignedLong() {
        numberTestHelper(UInt64.self, packetType: .unsignedLong)
    }

    func testFloat() {
        for _ in 1...2000 {
            let x = Float32.random(
                in: Float32(Int32.min)...Float32(Int32.max))
            var buffer = allocator.buffer(capacity: 4)
            buffer.writeInteger(x.bitPattern, as: UInt32.self)
            var packet = TestPacket(definition: [(name: "data",
                                                  type: .float,
                                                  args: nil)])
            try! packet.decode(buffer: &buffer)

            XCTAssertEqual(packet.data["data"] as! Float32, x)
        }
    }

    func testDouble() {
        for _ in 1...2000 {
            let x = Float64.random(
                in: Float64(Int64.min)...Float64(Int64.max))
            var buffer = allocator.buffer(capacity: 8)
            buffer.writeInteger(x.bitPattern, as: UInt64.self)
            var packet = TestPacket(definition: [(name: "data",
                                                  type: .double,
                                                  args: nil)])
            try! packet.decode(buffer: &buffer)

            XCTAssertEqual(packet.data["data"] as! Float64, x)
        }
    }

    func testUUID() {
        for _ in 1...2000 {
            let x = UUID()
            var buffer = allocator.buffer(bytes: [
                x.uuid.0,  x.uuid.1,  x.uuid.2,  x.uuid.3,
                x.uuid.4,  x.uuid.5,  x.uuid.6,  x.uuid.7,
                x.uuid.8,  x.uuid.9,  x.uuid.10, x.uuid.11,
                x.uuid.12, x.uuid.13, x.uuid.14, x.uuid.15
            ])
            var packet = TestPacket(definition: [(name: "data",
                                                  type: .uuid,
                                                  args: nil)])
            try! packet.decode(buffer: &buffer)

            XCTAssertEqual(packet.data["data"] as! UUID, x)
        }
    }

    func testString() {
        for _ in 1...2000 {
            let x = String(UUID().uuidString)
            var buffer = allocator.buffer(bytes: x.utf8)
            var packet = TestPacket(definition: [(name: "data",
                                                  type: .string,
                                                  args: ["length": x.utf8.count])])
            try! packet.decode(buffer: &buffer)

            XCTAssertEqual(packet.data["data"] as! String, x)
        }
    }

    func testVarInt() {
        for varInt in varIntData {
            var buffer = allocator.buffer(bytes: varInt.bytes)

            var packet = TestPacket(definition: [(name: "var_int",
                                                  type: .varInt,
                                                  args: nil)])
            try! packet.decode(buffer: &buffer)

            XCTAssertEqual(packet.data["var_int"] as! Int32, Int32(varInt.value))
            // will remake the encode test when the encoder is made
            // XCTAssertEqual(buffer.readBytes(length: varInt.bytes.count), varInt.bytes)
        }
    }

    func testVarLong() {
        for varLong in varLongData {
            var buffer = allocator.buffer(bytes: varLong.bytes)

            var packet = TestPacket(definition: [(name: "var_long",
                                                  type: .varLong,
                                                  args: nil)])
            try! packet.decode(buffer: &buffer)

            XCTAssertEqual(packet.data["var_long"] as! Int64, Int64(varLong.value))
//            XCTAssertEqual(buffer.readBytes(length: varLong.bytes.count), varLong.bytes)
        }
    }

    func testVarString() {
        for _ in 1...2000 {
            let x = String(UUID().uuidString)
            var buffer = allocator.buffer(capacity: x.utf8.count + (Int32.bitWidth / 8))
            buffer.writeVarInt(Int32(x.utf8.count))
            buffer.writeBytes(x.utf8)
            var packet = TestPacket(definition: [(name: "data",
                                                  type: .varString,
                                                  args: ["length": x.utf8.count])])
            try! packet.decode(buffer: &buffer)

            XCTAssertEqual(packet.data["data"] as! String, x)
        }
    }

    func numberTestHelper<T: FixedWidthInteger>(_: T.Type, packetType: PacketData) {
        for _ in 1...2000 {
            let x = T.random(in: T.min...T.max)
            var buffer = allocator.buffer(capacity: T.bitWidth / 8)
            buffer.writeInteger(x, as: T.self)
            var packet = TestPacket(definition: [(name: "data",
                                                  type: packetType,
                                                  args: nil),])
            try! packet.decode(buffer: &buffer)

            XCTAssertEqual(packet.data["data"] as! T, x)
        }
        var buffer = allocator.buffer(capacity: (T.bitWidth / 8) * 3)
        buffer.writeInteger(T.min, as: T.self)
        buffer.writeInteger(0, as: T.self)
        buffer.writeInteger(T.max, as: T.self)
        var packet = TestPacket(definition: [(name: "min",
                                              type: packetType,
                                              args: nil),
                                             (name: "zero",
                                              type: packetType,
                                              args: nil),
                                             (name: "max",
                                              type: packetType,
                                              args: nil)])
        try! packet.decode(buffer: &buffer)

        XCTAssertEqual(packet.data["min"] as! T, T.min)
        XCTAssertEqual(packet.data["zero"] as! T, 0)
        XCTAssertEqual(packet.data["max"] as! T, T.max)
    }

    static var allTests = [
        ("testBoolean",         testBoolean),
        ("testByte",            testByte),
        ("testUnsignedByte",    testUnsignedByte),
        ("testByteArray",       testByteArray),
        ("testShort",           testShort),
        ("testUnsignedShort",   testUnsignedShort),
        ("testInt",             testInt),
        ("testUnsignedInt",     testUnsignedInt),
        ("testLong",            testLong),
        ("testUnsignedLong",    testUnsignedLong),
        ("testFloat",           testFloat),
        ("testDouble",          testDouble),
        ("testUUID",            testUUID),
        ("testString",          testString),
        ("testVarInt",          testVarInt),
        ("testVarLong",         testVarLong),
        ("testVarString",       testVarString),
    ]
}
