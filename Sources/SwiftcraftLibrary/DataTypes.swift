//
//  DataTypes.swift
//  Swiftcraft
//
//  Created by Marz Rover on 11/21/20.
//

import Foundation
import NIO

typealias Byte = UInt8
typealias ByteArray = [Byte]

enum VarIntError: Error {
    case varIntIsTooBig
}

enum VarLongError: Error {
    case varLongIsTooBig
}

extension Int32 {
    init(buffer byteBuffer: inout ByteBuffer) throws {
        self.init()
        var result: Self = 0
        var shift = 0
        var input: Byte
        repeat {
            input = Byte(byteBuffer.readBytes(length: 1)![0])
            result |= Self((input & Byte(0x7F)) << (shift * 7))
            shift += 1
            if (shift > 5) {
                throw VarIntError.varIntIsTooBig
            }
        } while ((input & 0x80) != 0x80)
        self = result
    }
    
    var varInt: ByteArray {
        var out: ByteArray = []
        var part: Byte
        var value = self
        repeat {
            part = Byte(value & 0x7F)
            value >>= 7
            if (value != 0) {
                part |= 0x80
            }
            out.append(part)
        } while (value == 0)
        return out
    }
}

extension Int64 {
    init(buffer byteBuffer: inout ByteBuffer) throws {
        self.init()
        var result: Self = 0
        var shift = 0
        var input: Byte
        repeat {
            input = Byte(byteBuffer.readBytes(length: 1)![0])
            result |= Self((input & Byte(0x7F)) << (shift * 7))
            shift += 1
            if (shift > 10) {
                throw VarLongError.varLongIsTooBig
            }
        } while ((input & 0x80) != 0x80)
        self = result
    }
    
    var varLong: ByteArray {
        var out: ByteArray = []
        var part: Byte
        var value = self
        repeat {
            part = Byte(value & 0x7F)
            value >>= 7
            if (value != 0) {
                part |= 0x80
            }
            out.append(part)
        } while (value == 0)
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
