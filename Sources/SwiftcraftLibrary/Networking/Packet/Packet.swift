//
//  Packet.swift
//  
//
//  Created by Marz Rover on 12/2/20.
//

import NIO

/// Name of a datatype that is usable in a packet.
/// Value is set to a string, this string shows the Swift datatype and any arguments needed for a read.
enum PacketData: String {
    case unsignedShort = "UInt16"
    case varInt = "Int32"
    case varLong = "Int64"
    case varString = "String"
    case string = "String(length: Int)"
}

/// A Packet must have these fields.
protocol Packet {
    var buffer: ByteBuffer { get set }
    var data: [String:Any] { get set }
    var definition: [(name: String, type: PacketData, args: [String:Any]?)] { get }
    var id: Int32 { get }
    var length: Int32 { get }
}

/// Because of a definition field we can quickly and easily decode / encode packets
extension Packet {
    mutating func decode() throws {
        for def in definition {
            switch def.type {
                case .unsignedShort:
                    data[def.name] = buffer.readUInt16()
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
                case .string:
                    data[def.name] = buffer.readString(length: def.args!["length"] as! Int)
                    break
            }
        }
    }
}
