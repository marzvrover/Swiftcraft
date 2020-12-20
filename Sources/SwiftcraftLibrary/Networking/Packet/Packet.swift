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
// MARK: Packet
/// Packet class. This is the base class for all Packets.
class Packet: PacketProtocol & Equatable {
    /// Conform to `Equatable` using `AnyHashable` to determine if values of type `Any` are equal.
    ///
    /// - note: There has to be a better way to this.
    ///         But seeing as we shouldn't have to compare `Packet`s often besides in tests this will do for now.
    static func == (lhs: Packet, rhs: Packet) -> Bool { // swiftlint:disable:this cyclomatic_complexity
        guard lhs.id == rhs.id else {
            return false
        }
        guard lhs.definition.count == rhs.definition.count else {
            return false
        }
        guard lhs.data.count == rhs.data.count else {
            return false
        }
        for (key, value) in lhs.data {
            guard rhs.data.keys.contains(key) else {
                return false
            }
            guard value is AnyHashable else {
                return false
            }
            let rvalue = rhs.data[key]
            guard rvalue is AnyHashable else {
                return false
            }
            // swiftlint:disable:next force_cast
            guard value as! AnyHashable == rvalue as! AnyHashable else {
                return false
            }
        }
        for (index, (name, type, args)) in lhs.definition.enumerated() {
            guard name == rhs.definition[index].name else {
                return false
            }
            guard type == rhs.definition[index].type else {
                return false
            }
            guard args != nil else {
                if rhs.definition[index].args == nil {
                    continue
                }
                return false
            }
            for (key, value) in args! {
                guard rhs.definition[index].args!.keys.contains(key) else {
                    return false
                }
                guard value is AnyHashable else {
                    return false
                }
                let rvalue = rhs.definition[index].args![key]
                guard rvalue is AnyHashable else {
                    return false
                }
                // swiftlint:disable:next force_cast
                guard (value as! AnyHashable) == (rvalue as! AnyHashable) else {
                    return false
                }
            }
        }

        return true
    }

    var data: [String: Any]
    var definition: Definition
    var id: Int32 // swiftlint:disable:this identifier_name

    // swiftlint:disable:next identifier_name
    internal init(id: Int32, definition: Definition, data: [String: Any]) {
        self.id = id
        self.definition = definition
        self.data = data
    }
}

/// A Packet must have these fields.
protocol PacketProtocol {
    typealias Definition = [(name: String, type: PacketData, args: [String: Any]?)]
    /// This is where the key=>value pairs from the packet are stored.
    var data: [String: Any] { get set }
    /// Defines how to decode the packet
    var definition: Definition { get }
    /// The packet's Minecraft ID
    var id: Int32 { get } // swiftlint:disable:this identifier_name
}
/// Because of a definition field we can quickly and easily decode / encode packets
extension PacketProtocol {
    // MARK: Packet.decode
    /// Decode the pack according to the `Packet`.`definition` field.
    /// Load the results into the `Packet`.`data` field.
    ///
    /// - parameters:
    ///     - buffer: `inout` `ByteBuffer`. The `ByteBuffer` to work on.
    ///     - definition: A `Packet`.`Definition` to override the packet's own definition field.
    /// - throws: Could through various errors relating to reading the datatypes from the `ByteBuffer`.
    ///     - Every error in `VarIntErrors`
    ///     - Every error in `VarLongErrors`
    mutating func decode(buffer: inout ByteBuffer, // swiftlint:disable:this function_body_length cyclomatic_complexity
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
                case .byte:
                    data[def.name] = buffer.readInteger(as: Int8.self)
                case .unsignedByte:
                    data[def.name] = buffer.readInteger(as: UInt8.self)
                case .byteArray:
                    // swiftlint:disable:next force_cast
                    data[def.name] = buffer.readBytes(length: def.args!["length"] as! Int)
                case .short:
                    data[def.name] = buffer.readInteger(as: Int16.self)
                case .unsignedShort:
                    data[def.name] = buffer.readInteger(as: UInt16.self)
                case .int:
                    data[def.name] = buffer.readInteger(as: Int32.self)
                case .unsignedInt:
                    data[def.name] = buffer.readInteger(as: UInt32.self)
                case .long:
                    data[def.name] = buffer.readInteger(as: Int64.self)
                case .unsignedLong:
                    data[def.name] = buffer.readInteger(as: UInt64.self)
                case .float:
                    data[def.name] = Float32(bitPattern: buffer.readInteger(as: UInt32.self)!)
                case .double:
                    data[def.name] = Float64(bitPattern: buffer.readInteger(as: UInt64.self)!)
                case .uuid:
                    // swiftlint:disable:next identifier_name
                    let b = buffer.readBytes(length: 16)!
                    // swiftlint:disable:next comma
                    let uuid: uuid_t = (b[0], b[1], b[2],  b[3],  b[4],  b[5],  b[6],  b[7],
                                        b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15])
                    data[def.name] = UUID(uuid: uuid)
                case .string:
                    // swiftlint:disable:next force_cast
                    data[def.name] = buffer.readString(length: def.args!["length"] as! Int)
                case .varInt:
                    data[def.name] = try buffer.readVarInt()
                case .varLong:
                    data[def.name] = try buffer.readVarLong()
                case .varString:
                    data[def.name] = try buffer.readVarString()
            }
        }
    }
    // MARK: Packet.encode
    /// Encode the pack according to the `Packet`.`definition` field.
    /// Load the data from the `Packet`.`data` field.
    ///
    /// - parameters:
    ///     - buffer: `inout` `ByteBuffer`. The `ByteBuffer` to write to.
    ///     - definition: A `Packet`.`Definition` to override the packet's own definition field.
    /// - throws: Could through various errors relating to reading the datatypes from the `ByteBuffer`.
    ///     - Every error in `VarIntErrors`
    ///     - Every error in `VarLongErrors`
    func encode(buffer: inout ByteBuffer, // swiftlint:disable:this function_body_length cyclomatic_complexity
                definition inDefinition: Definition? = nil) {
        var workingDef: Definition
        if inDefinition == nil {
            workingDef = definition
        } else {
            workingDef = inDefinition!
        }
        var tmpBuffer = ByteBufferAllocator().buffer(buffer: buffer)
        for def in workingDef {
            switch def.type {
                case .boolean:
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeBool(data[def.name] as! Bool)
                case .byte:
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeByte(UInt8(bitPattern: data[def.name] as! Int8))
                case .unsignedByte:
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeByte(data[def.name] as! UInt8)
                case .byteArray:
                    // swiftlint:disable:next force_cast
                    let out: [UInt8] = data[def.name] as! [UInt8]
                    tmpBuffer.reserveCapacity(out.count)
                    tmpBuffer.writeBytes(out)
                case .short:
                    tmpBuffer.reserveCapacity(2) // 16 bits
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeInteger(data[def.name] as! Int16, as: Int16.self)
                case .unsignedShort:
                    tmpBuffer.reserveCapacity(2) // 16 bits
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeInteger(data[def.name] as! UInt16, as: UInt16.self)
                case .int:
                    tmpBuffer.reserveCapacity(4) // 32 bits
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeInteger(data[def.name] as! Int32, as: Int32.self)
                case .unsignedInt:
                    tmpBuffer.reserveCapacity(4) // 32 bits
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeInteger(data[def.name] as! UInt32, as: UInt32.self)
                case .long:
                    tmpBuffer.reserveCapacity(8) // 64 bits
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeInteger(data[def.name] as! Int64, as: Int64.self)
                case .unsignedLong:
                    tmpBuffer.reserveCapacity(8) // 64 bits
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeInteger(data[def.name] as! UInt64, as: UInt64.self)
                case .float:
                    tmpBuffer.reserveCapacity(4) // 32 bits
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeInteger((data[def.name] as! Float32).bitPattern, as: UInt32.self)
                case .double:
                    tmpBuffer.reserveCapacity(8) // 64 bits
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeInteger((data[def.name] as! Float64).bitPattern, as: UInt64.self)
                case .uuid:
                    tmpBuffer.reserveCapacity(16) // 128 bits
                    // swiftlint:disable:next force_cast
                    let uuid = (data[def.name] as! UUID).uuid
                    let bytes = [uuid.0, uuid.1, uuid.2, uuid.3, uuid.4, uuid.5, uuid.6, uuid.7,
                                 uuid.8, uuid.9, uuid.10, uuid.11, uuid.12, uuid.13, uuid.14, uuid.15]
                    // swiftlint:disable:previous trailing_comma
                    tmpBuffer.writeBytes(bytes)
                case .string:
                    // swiftlint:disable:next force_cast
                    tmpBuffer.reserveCapacity((data[def.name] as! String).utf8.count)
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeString(data[def.name] as! String)
                case .varInt:
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeVarInt(data[def.name] as! Int32)
                case .varLong:
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeVarLong(data[def.name] as! Int64)
                case .varString:
                    // swiftlint:disable:next force_cast
                    tmpBuffer.writeVarString(data[def.name] as! String)
            }
        }
        let length: Int32 = Int32(tmpBuffer.readableBytes)
        buffer.writeVarInt(length)
        buffer.writeVarInt(self.id)
        buffer.reserveCapacity(buffer.readableBytes + Int(length))
        buffer.writeBuffer(&tmpBuffer)
    }
}
