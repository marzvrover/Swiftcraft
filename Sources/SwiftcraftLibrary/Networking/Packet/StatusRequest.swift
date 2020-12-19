import Foundation
import NIO

/// # The Minecraft Server Bound Status Request `Packet`
///
/// ## ID
/// The `Packet`.`id` for the Minecraft Server Bound Status Request Packet is 0x00
///
/// ## Definition
/// empty
class StatusRequest: Packet {
    /// Server Bound Status Request Initializer
    init() {
        super.init(
            id: 0x00,
            definition: [],
            data: [:]
        )
    }
}
