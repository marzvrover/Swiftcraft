import Foundation
import NIO

/// # The Minecraft Server Bound Status Request `Packet`
///
/// ## ID
/// The `Packet`.`id` for the Minecraft Server Bound Status Request Packet is Protocol754.StatusServerbound.requestID
///
/// ## Definition
/// empty
class StatusRequest: Packet {
    /// Server Bound Status Request Initializer
    init() {
        super.init(
            id: Protocol754.StatusServerbound.requestID,
            definition: [],
            data: [:]
        )
    }
}
