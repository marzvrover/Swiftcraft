import Foundation

// StatusInfo
// Represents the status information of the server.
struct StatusInfo: Encodable {
    struct Version: Encodable {
        let name: String
        let `protocol`: Int
    }

    struct Players: Encodable {
        let max: Int
        let online: Int
    }

    struct Description: Encodable {
        let text: String
    }

    let version: Version
    let players: Players
    let description: Description

    init(configuration: ServerConfiguration) {
        self.version = Version(
            name: configuration.protocolVersion.implementationVersionName,
            protocol: configuration.protocolVersion.rawValue
        )
        self.players = Players(
            max: configuration.maxPlayers,
            online: 0
        )
        self.description = Description(
            text: configuration.motd
        )
    }
}

// Represents the status response packet sent by the server.
final class StatusResponse: Packet {
    // MARK: Initialization
    /// Initializes a `StatusResponse` packet with the given JSON string.
    ///
    /// - parameter json: The JSON string representing the status information.
    init(json: String) {
        super.init(
            id: 0x00,
            definition: [
                (name: "json", type: .varString, args: nil)
            ],
            data: ["json": json]
        )
    }
}
