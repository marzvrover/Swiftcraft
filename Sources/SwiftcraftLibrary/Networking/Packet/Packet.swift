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
    /// Minecraft `Boolean` is a `Bool`
    case boolean = "Bool"
    /// Minecraft `Byte` is a `Int8`
    case byte = "Int8"
    /// Minecraft `Unsigned Byte` is a `UInt8`
    case unsignedByte = "UInt8"
    /// Minecraft `ByteArray` is a `[UInt8]`.
    /// To read it from the `ByteBuffer` you must know its length.
    case byteArray = "[UInt8](length: Int)"
    /// Minecraft `Short` is a `Int16`
    case short = "Int16"
    /// Minecraft `Unsigned Short` is a `UInt16`
    case unsignedShort = "UInt16"
    /// Minecraft `Int` is a `Int32`
    case int = "Int32"
    /// Minecraft `Unsigned Int` is a `UInt32`
    case unsignedInt = "UInt32"
    /// Minecraft `Long` is a `Int64`
    case long = "Int64"
    /// Minecraft `Unsigned Long` is a `UInt64`
    case unsignedLong = "UInt64"
    /// Minecraft `Float` is a `Float32`
    case float = "Float32"
    /// Minecraft `Double` is a `Float64`
    case double = "Float64"
    /// Minecraft `UUID` is a `UUID`
    case uuid = "UUID"
    /// Minecraft `String` is a `String`.
    /// To read it from the `ByteBuffer` you must know its length.
    case string = "String(length: Int)"
    /// Minecraft `VarInt` is a `Int32`
    case varInt = "vInt32"
    /// Minecraft `VarLong` is a `Int64`
    case varLong = "vInt64"
    /// Minecraft `VarString` is a `String`
    case varString = "String"
}

/// A Packet must have these fields.
protocol Packet {
    typealias Definition = [(name: String, type: PacketData, args: [String:Any]?)]
    /// This is where the key=>value pairs from the packet are stored.
    var data: [String:Any] { get set }
    /// Defines how to decode the packet
    var definition: Definition { get }
    /// The packet's Minecraft ID
    var id: Int32 { get }
}

/// Because of a definition field we can quickly and easily decode / encode packets
extension Packet {
    /// Decode the pack according to the `Packet`.`definition` field.
    /// Load the results into the `Packet`.`data` field.
    ///
    /// - parameters:
    ///     - buffer: `inout` `ByteBuffer`. The `ByteBuffer` to work on.
    ///     - definition: A `Packet`.`Definition` to override the packet's own definition field.
    /// - throws: Could through various errors relating to reading the datatypes from the `ByteBuffer`.
    ///     - Every error in `VarIntErrors`
    ///     - Every error in `VarLongErrors`
    mutating func decode(buffer: inout ByteBuffer,
                         definition inDefinition: Definition? = nil) throws {
        var workingDef: Definition
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
