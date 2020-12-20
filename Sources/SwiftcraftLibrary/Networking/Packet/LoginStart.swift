import Foundation
import NIO

/// # The Minecraft Login Start `Packet`
///
/// ## ID
/// The `Packet`.`id` for the Minecraft Login Start Packet is 0x00
///
/// ## Definition
///
/// Field Name       | Datatype                                  | Decoder Arguments | Notes
/// -----------------|-------------------------------------------|-------------------|--------------------
/// Name             | `PacketData`.`varString`                  |                   | Player's username
///
/// - note: The protocol claims that name is a `PacketData`.`string` of length 16,
///         but I have found it to be a `PacketData`.`varString`.
class LoginStart: Packet {
    /// LoginStart Initializer
    init() {
        super.init(
            id: 0x00,
            definition: [
                (name: "name", type: .varString, args: nil),
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
