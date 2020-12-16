//
//  DataTypes.swift
//  Swiftcraft
//
//  Created by Marz Rover on 11/21/20.
//

import Foundation
import NIO

/// A `Byte` is of the type `UInt8`
public typealias Byte = UInt8
/// `Error` `enum` for `VarInt`
enum VarIntError: Error {
    /// Too many `Byte`s for the data to be a `PacketData`.`varInt`
    case varIntIsTooBig
}
/// `Error` `enum` for `VarLong`
enum VarLongError: Error {
    /// Too many `Byte`s for the data to be a `PacketData`.`varLong`
    case varLongIsTooBig
}

/// Extend `ByteBuffer` to add reading and writing Minecraft DataTypes
extension ByteBuffer {
    /// Write a `Bool` into this `ByteBuffer`, move the writer index forward by number of bytes written.
    ///
    /// - parameters:
    ///     - bool: A `Bool` value to write to the `ByteBuffer`
    public mutating func writeBool(_ bool: Bool) {
        self.writeByte(bool ? 0x01 : 0x00)
    }
    /// Write a `Byte` into this `ByteBuffer`, move the writer index forward by number of bytes written.
    ///
    /// - parameters:
    ///     - byte: A `Bool` value to write to the `ByteBuffer`
    public mutating func writeByte(_ byte: Byte) {
        self.reserveCapacity(1)
        self.writeBytes([byte])
    }
    /// Read a `Byte` off this `ByteBuffer`, move the reader index forward by one byte.
    ///
    /// - returns: A `Byte` value deserialized from this `ByteBuffer` or `nil` if there aren't enough bytes readable.
    @discardableResult
    @inlinable
    public mutating func readByte() -> Byte? {
        return self.readBytes(length: 1)?[0]
    }
    /// Read a `PacketData`.`varInt` off this `ByteBuffer`, move the reader index forward by the size in bytes..
    ///
    /// - returns: A `Int32` value deserialized from this `ByteBuffer`.
    /// - throws: Throws `VarIntError.VarIntIsTooBig`
    @discardableResult
    public mutating func readVarInt() throws -> Int32 {
        var result: UInt32 = 0
        var shift = 0
        var input: Byte
        repeat {
            input = self.readByte()!
            result |= UInt32(input & Byte(0x7F)) << UInt32(shift * 7)
            shift += 1
            if (shift > 5) {
                throw VarIntError.varIntIsTooBig
            }
        } while ((input & 0x80) != 0)

        return Int32(bitPattern: result)
    }
    /// Write a `PacketData`.`varInt` into this `ByteBuffer`, move the writer index forward by number of bytes written.
    ///
    /// - parameters:
    ///     - varInt: A `Int32` value to write as a `PacketData`.`varInt`
    public mutating func writeVarInt(_ varInt: Int32) {
        var out: [Byte] = []
        var part: Byte
        var value: UInt32 = UInt32(bitPattern: varInt)

        repeat {
            part = Byte(value & 0x7F)
            value >>= 7
            if (value != 0) {
                part |= 0x80
            }
            out.append(part)
        } while (value != 0)

        self.reserveCapacity(out.count)
        self.writeBytes(out)
    }
    /// Read a `PacketData`.`varLong` off this `ByteBuffer`, move the reader index forward by the size in bytes..
    ///
    /// - returns: A `Int64` value deserialized from this `ByteBuffer`.
    /// - throws: `VarLongError.VarLongIsTooBig`
    @discardableResult
    public mutating func readVarLong() throws -> Int64 {
        var result: UInt64 = 0
        var shift = 0
        var input: Byte

        repeat {
            input = self.readByte()!
            result |= UInt64(input & Byte(0x7F)) << UInt64(shift * 7)
            shift += 1
            if (shift > 10) {
                throw VarLongError.varLongIsTooBig
            }
        } while ((input & 0x80) != 0)

        return Int64(bitPattern: result)
    }
    /// Write a `PacketData`.`varLong` into this `ByteBuffer`, move the writer index forward by number of bytes written.
    ///
    /// - parameters:
    ///     - varInt: A `Int64` value to write as a `PacketData`.`varLong`
    public mutating func writeVarLong(_ varLong: Int64) {
        var out: [Byte] = []
        var part: Byte
        var value: UInt64 = UInt64(bitPattern: varLong)
        repeat {
            part = Byte(value & 0x7F)
            value >>= 7
            if (value != 0) {
                part |= 0x80
            }
            out.append(part)
        } while (value != 0)

        self.reserveCapacity(out.count)
        self.writeBytes(out)
    }
    /// Read a `PacketData`.`varString` off this `ByteBuffer`, move the reader index forward by the size in bytes.
    ///
    /// - returns: A `String` value deserialized from this `ByteBuffer` or `nil` if there aren't enough bytes readable.
    @discardableResult
    public mutating func readVarString() throws -> String? {
        let length = Int(try self.readVarInt())
        return self.readString(length: length)
    }
    /// Write a `PacketData`.`varString` onto this `ByteBuffer`, move the writer index forward by the size in bytes.
    ///
    /// - parameters:
    ///     - varString: A `String` value to write as a `PacketData`.`varString`
    public mutating func writeVarString(_ varString: String) {
        let length = varString.utf8.count
        self.writeVarInt(Int32(length))
        self.reserveCapacity(length)
        self.writeString(varString)
    }
}
