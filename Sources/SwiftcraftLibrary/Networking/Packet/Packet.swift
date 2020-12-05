//
//  Packet.swift
//
//
//  Created by Marz Rover on 12/2/20.
//

import Foundation
import NIO

/// Name of a datatype that is usable in a packet.
/// Value is set to a string, this string shows the Swift datatype and any arguments needed for a read.
enum PacketData: String {
    case boolean = "Bool"
    case byte = "Int8"
    case unsignedByte = "UInt8"
    case byteArray = "[UInt8](length: Int)"
    case short = "Int16"
    case unsignedShort = "UInt16"
    case int = "Int32"
    case unsignedInt = "UInt32"
    case long = "Int64"
    case unsignedLong = "UInt64"
    case float = "Float32"
    case double = "Float64"
    case uuid = "UUID"
    case string = "String(length: Int)"
    case varInt = "vInt32"
    case varLong = "vInt64"
    case varString = "String"
}

/// A Packet must have these fields.
protocol Packet {
    var data: [String:Any] { get set }
    var definition: [(name: String, type: PacketData, args: [String:Any]?)] { get }
    var id: Int32 { get }
}

/// Because of a definition field we can quickly and easily decode / encode packets
extension Packet {
    mutating func decode(buffer: inout ByteBuffer,
                         definition inDefinition: [(name: String,
                                                    type: PacketData,
                                                    args: [String:Any]?)]? = nil) throws {
        var workingDef: [(name: String, type: PacketData, args: [String:Any]?)]
        if inDefinition == nil {
            workingDef = definition
        } else {
            workingDef = inDefinition!
        }
        for def in workingDef {
            switch def.type {
                case .boolean:
                    data[def.name] = buffer.readByte()! != 0x00
                    break
                case .byte:
                    data[def.name] = buffer.readInteger(as: Int8.self)
                    break
                case .unsignedByte:
                    data[def.name] = buffer.readInteger(as: UInt8.self)
                    break
                case .byteArray:
                    data[def.name] = buffer.readBytes(length: def.args!["length"] as! Int)
                    break
                case .short:
                    data[def.name] = buffer.readInteger(as: Int16.self)
                    break
                case .unsignedShort:
                    data[def.name] = buffer.readInteger(as: UInt16.self)
                    break
                case .int:
                    data[def.name] = buffer.readInteger(as: Int32.self)
                    break
                case .unsignedInt:
                    data[def.name] = buffer.readInteger(as: UInt32.self)
                    break
                case .long:
                    data[def.name] = buffer.readInteger(as: Int64.self)
                    break
                case .unsignedLong:
                    data[def.name] = buffer.readInteger(as: UInt64.self)
                    break
                case .float:
                    data[def.name] = Float32(bitPattern: buffer.readInteger(as: UInt32.self)!)
                    break
                case .double:
                    data[def.name] = Float64(bitPattern: buffer.readInteger(as: UInt64.self)!)
                    break
                case .uuid:
                    let b = buffer.readBytes(length: 16)!
                    let uuid: uuid_t = (b[0], b[1], b[2],  b[3],  b[4],  b[5],  b[6],  b[7],
                                        b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15])
                    data[def.name] = UUID(uuid: uuid)
                    break
                case .string:
                    data[def.name] = buffer.readString(length: def.args!["length"] as! Int)
                    break
                case .varInt:
                    data[def.name] = try buffer.readVarInt()
                    break
                case .varLong:
                    data[def.name] = try buffer.readVarLong()
                    break
                case .varString:
                    data[def.name] = try buffer.readVarString()
                    break
            }
        }
    }
}
