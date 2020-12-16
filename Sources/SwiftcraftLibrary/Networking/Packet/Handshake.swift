import Foundation
import NIO

/// # The Minecraft Handshake `Packet`
///
/// ## ID
/// The `Packet`.`id` for the Minecraft Handshake Packet is 0x00
///
/// ## Definition
///
/// Field Name       | Datatype                                  | Decoder Arguments | Notes
/// -----------------|-------------------------------------------|-------------------|-------------------------------------------------
/// protocol_version | `PacketData`.`varInt` aka `Int32`         |                   | The Minecraft Protocol version number.
/// server_address   | `PacketData`.`varString` aka `String`     |                   | The server address the client is connecting to.
/// server_port      | `PacketData`.`unsignedShort` aka `UInt16` |                   | The server port the client is connecting to.
/// intention        | `PacketData`.`varInt` aka `Int32`         |                   | 1 for status, 2 for login
class Handshake: Packet {
    /// Handshake Initializer
    init() {
        super.init(
            id: 0x00,
            definition: [
                (name: "protocol_version", type: .varInt, args: nil),
                (name: "server_address", type: .varString, args: nil),
                (name: "server_port", type: .unsignedShort, args: nil),
                (name: "intention", type: .varInt, args: nil),
            ],
            data: [:]
        )
    }
    /// Getter and setter for `Handshake`.`data["protocol_version"]`.
    var version: Int32 {
        get {
            return self.data["protocol_version"] as! Int32
        }
        set(value) {
            self.data["protocol_version"] = value
        }
    }
    /// Getter and setter for `Handshake`.`data["server_address"]`.
    var address: String {
        get {
            return self.data["server_address"] as! String
        }
        set(value) {
            self.data["server_address"] = value
        }
    }
    /// Getter and setter for `Handshake`.`data["server_port"]`.
    var port: UInt16 {
        get {
            return self.data["server_port"] as! UInt16
        }
        set(value) {
            self.data["server_port"] = value
        }
    }
    /// Getter and setter for `Handshake`.`data["intention"]`.
    var intention: Int32 {
        get {
            return self.data["intention"] as! Int32
        }
        set(value) {
            self.data["intention"] = value
        }
    }
}
