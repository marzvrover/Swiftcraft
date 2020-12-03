//
//  DataTypes.swift
//  Swiftcraft
//
//  Created by Marz Rover on 11/21/20.
//

import Foundation
import NIO

public typealias Byte = UInt8
public typealias ByteArray = [Byte]

enum VarIntError: Error {
    case varIntIsTooBig
}

enum VarLongError: Error {
    case varLongIsTooBig
}

extension ByteBuffer {
    /// Read a `Byte` off this `ByteBuffer`, move the reader index forward by one byte.
    ///
    /// - returns: A `Byte` value deserialized from this `ByteBuffer` or `nil` if there aren't enough bytes readable.
    @discardableResult
    @inlinable
    public mutating func readByte() -> Byte? {
        return self.readBytes(length: 1)?[0]
    }

    /// Read a `VarInt` off this `ByteBuffer`, move the reader index forward by the size in bytes..
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

    /// Read a `VarLong` off this `ByteBuffer`, move the reader index forward by the size in bytes..
    ///
    /// - returns: A `Int64` value deserialized from this `ByteBuffer`.
    /// - throws: `VarLongError.VarLongIsTooBig`
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

    /// Read a `UInt16` off this `ByteBuffer`, move the reader index forward by the size in bytes..
    ///
    /// - returns: A `UInt16` value deserialized from this `ByteBuffer` or `nil` if there aren't enough bytes readable.
    @discardableResult
    @inlinable
    public mutating func readUInt16() -> UInt16? {
        return self.readInteger(as: UInt16.self)
    }

    /// Read a `VarString` off this `ByteBuffer`, move the reader index forward by the size in bytes..
    ///
    /// - returns: A `String` value deserialized from this `ByteBuffer` or `nil` if there aren't enough bytes readable.
    @discardableResult
    public mutating func readVarString() throws -> String? {
        let length = Int(try self.readVarInt())
        return self.readString(length: length)
    }
}
