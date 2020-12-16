import XCTest
import class Foundation.Bundle
import NIO
@testable import SwiftcraftLibrary

final class DataTypeTests: XCTestCase {
    class TestPacket: Packet {
        init(definition: Definition) {
            super.init(
                id: Int32.min,
                definition: definition,
                data: [:]
                )
        }
    }

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

        buffer.reserveCapacity(2)
        packet.encode(buffer: &buffer)
        XCTAssertEqual(buffer.readBytes(length: 2), [0x01, 0x00])
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

            buffer.reserveCapacity(bytes.count)
            packet.encode(buffer: &buffer)
            XCTAssertEqual(buffer.readBytes(length: bytes.count), bytes)
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

            buffer.reserveCapacity(32)
            packet.encode(buffer: &buffer)
            XCTAssertEqual(Float32(bitPattern: buffer.readInteger(as: UInt32.self)!), x)
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

            buffer.reserveCapacity(64)
            packet.encode(buffer: &buffer)
            XCTAssertEqual(Float64(bitPattern: buffer.readInteger(as: UInt64.self)!), x)
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

            buffer.reserveCapacity(128)
            packet.encode(buffer: &buffer)
            let byteArray = buffer.readBytes(length: 16)!
            let uuid: uuid_t = (byteArray[0],  byteArray[1],  byteArray[2],  byteArray[3],
                                byteArray[4],  byteArray[5],  byteArray[6],  byteArray[7],
                                byteArray[8],  byteArray[9],  byteArray[10], byteArray[11],
                                byteArray[12], byteArray[13], byteArray[14], byteArray[15])
            XCTAssertEqual(UUID(uuid: uuid), x)
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

            buffer.reserveCapacity(x.utf8.count)
            packet.encode(buffer: &buffer)
            XCTAssertEqual(buffer.readString(length: x.utf8.count), x)
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

            buffer.reserveCapacity(varInt.bytes.count)
            packet.encode(buffer: &buffer)
            XCTAssertEqual(buffer.readBytes(length: varInt.bytes.count), varInt.bytes)
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

            buffer.reserveCapacity(varLong.bytes.count)
            packet.encode(buffer: &buffer)
            XCTAssertEqual(buffer.readBytes(length: varLong.bytes.count), varLong.bytes)
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

            buffer.reserveCapacity(x.utf8.count + (Int32.bitWidth / 8))
            packet.encode(buffer: &buffer)
            let length = try! buffer.readVarInt()
            XCTAssertEqual(length, Int32(x.utf8.count))
            XCTAssertEqual(buffer.readString(length: Int(length)), x)
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

            buffer.reserveCapacity(T.bitWidth / 8)
            packet.encode(buffer: &buffer)
            XCTAssertEqual(buffer.readInteger(as: T.self), x)
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

        buffer.reserveCapacity((T.bitWidth / 8) * 3)
        packet.encode(buffer: &buffer)
        XCTAssertEqual(buffer.readInteger(as: T.self), T.min)
        XCTAssertEqual(buffer.readInteger(as: T.self), 0)
        XCTAssertEqual(buffer.readInteger(as: T.self), T.max)
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
