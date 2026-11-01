struct MinecraftVersion: Equatable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
}

enum Protocol754: Int, Equatable, Sendable {
    case v754 = 754

    var minimumMinecraftVersion: MinecraftVersion {
        switch self {
        case .v754:
            return MinecraftVersion(major: 1, minor: 16, patch: 5)
        }
    }

    var maximumMinecraftVersion: MinecraftVersion {
        switch self {
        case .v754:
            return MinecraftVersion(major: 1, minor: 16, patch: 5)
        }
    }

    var implementationVersionName: String {
        switch self {
        case .v754:
            return "1.16.5"
        }
    }

    enum Handshake {
        static let serverboundID: Int32 = 0x00
        static let statusIntention: Int32 = 1
        static let loginIntention: Int32 = 2
    }

    enum StatusServerbound {
        static let requestID: Int32 = 0x00
        static let pingID: Int32 = 0x01
    }

    enum StatusClientbound {
        static let responseID: Int32 = 0x00
        static let pongID: Int32 = 0x01
    }

    enum LoginServerbound {
        static let startID: Int32 = 0x00
    }

    enum LoginClientbound {
        static let disconnectID: Int32 = 0x00
    }

    enum WireLimits {
        static let varIntMaximumBytes = 5
        static let packetLengthMaximumBytes = 3
        static let packetLengthMaximum: Int32 = 2_097_151
        static let handshakeAddressMaximumCharacters = 255
        static let loginNameMaximumCharacters = 16
    }
}
