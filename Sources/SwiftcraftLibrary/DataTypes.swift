//
//  DataTypes.swift
//  Swiftcraft
//
//  Created by Marz Rover on 11/21/20.
//

import Foundation
import NIO

typealias Byte = UInt8

enum VarIntError: Error {
    case varIntIsTooBig
}

enum VarLongError: Error {
    case varLongIsTooBig
}

extension UInt8 {
    init(buffer byteBuffer: inout ByteBuffer) {
        self.init()
        self = Self(byteBuffer.readBytes(length: 1)![0])
    }
}

extension UInt16 {
    init(buffer byteBuffer: inout ByteBuffer) {
        self.init()
        self = byteBuffer.readInteger(as: Self.self)!
    }
}

extension Int32 {
    init(buffer byteBuffer: inout ByteBuffer) throws {
        self.init()
        var result: UInt32 = 0
        var shift = 0
        var input: Byte
        repeat {
            input = Byte(byteBuffer.readBytes(length: 1)![0])
            result |= UInt32(input & Byte(0x7F)) << UInt32(shift * 7)
            shift += 1
            if (shift > 5) {
                throw VarIntError.varIntIsTooBig
            }
        } while ((input & 0x80) != 0)
        self = Self(bitPattern: result)
    }

    var varInt: [Byte] {
        var out: [Byte] = []
        var part: Byte
        var value: UInt32 = UInt32(bitPattern: self)
        repeat {
            part = Byte(value & 0x7F)
            value >>= 7
            if (value != 0) {
                part |= 0x80
            }
            out.append(part)
        } while (value != 0)
        return out
    }
}

extension Int64 {
    init(buffer byteBuffer: inout ByteBuffer) throws {
        self.init()
        var result: UInt64 = 0
        var shift = 0
        var input: Byte
        repeat {
            input = Byte(byteBuffer.readBytes(length: 1)![0])
            result |= UInt64(input & Byte(0x7F)) << UInt64(shift * 7)
            shift += 1
            if (shift > 10) {
                throw VarLongError.varLongIsTooBig
            }
        } while ((input & 0x80) != 0)
        self = Self(bitPattern: result)
    }

    var varLong: [Byte] {
        var out: [Byte] = []
        var part: Byte
        var value: UInt64 = UInt64(bitPattern: self)
        repeat {
            part = Byte(value & 0x7F)
            value >>= 7
            if (value != 0) {
                part |= 0x80
            }
            out.append(part)
        } while (value != 0)
        return out
    }
}

extension String {
    init(buffer: inout ByteBuffer) throws {
        self.init()
        let length = Int(try! Int32(buffer: &buffer))
        self = buffer.readString(length: length)!
    }
}
