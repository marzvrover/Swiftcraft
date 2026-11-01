import Foundation
import NIO

/// # The Minecraft Login Start `Packet`
///
/// ## ID
/// The `Packet`.`id` for the Minecraft Login Start Packet is Protocol754.LoginServerbound.startID
///
/// ## Definition
///
/// Field Name       | Datatype                                  | Decoder Arguments | Notes
/// -----------------|-------------------------------------------|-------------------|--------------------
/// Name             | `PacketData`.`varString`                  |                   | Player's username
///
/// The player's username is a VarInt-length-prefixed UTF-8 String
/// limited to 16 characters, not a fixed 16-byte field.
/// The length prefix specifies the number of UTF-8 bytes that follow.
class LoginStart: Packet {
    /// LoginStart Initializer
    init() {
        super.init(
            id: Protocol754.LoginServerbound.startID,
            definition: [
                (name: "name", type: .varString, args: ["maxCharacters": 16]),
            ],
            data: [:]
        )
    }
    /// Getter and setter for `LoginStart`.`data["name"]`.
    var name: String {
        get {
            // swiftlint:disable:next force_cast
            return self.data["name"] as! String
        }
        set(value) {
            self.data["name"] = value
        }
    }
}
