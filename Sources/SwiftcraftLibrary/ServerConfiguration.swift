import Foundation
import DotEnv

enum ServerConfigurationError: Error, Equatable {
    case duplicateKey(String)
    case unknownKey(String)
    case invalidValue(key: String, value: String)
    case unsupportedProtocolVersion(Int32)
}

public struct ServerConfiguration: Sendable, Equatable {
    public static let SwiftcraftVersion = "0.0.1"
    public static let defaultHost = "127.0.0.1"
    public static let defaultPort = 25565
    public static let defaultProtocolVersion: Protocol754 = .v754
    public static let defaultMOTD = "Swiftcraft v\(SwiftcraftVersion)"
    public static let defaultMaxPlayers = 255
    public static let defaultLoginRejectionMessage =
        "Swiftcraft gameplay is not implemented yet."

    public let host: String
    public let port: Int
    public let protocolVersion: Protocol754
    public let motd: String
    public let maxPlayers: Int
    public let loginRejectionMessage: String

    public static func load(
        path: String = "server.properties",
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> ServerConfiguration {
        var fileValues: [String: String] = [:]

        if FileManager.default.fileExists(atPath: path) {
            let file = try DotEnv.read(path: path)
            for line in file.lines {
                guard fileValues.updateValue(line.value, forKey: line.key) ==
                nil else {
                    throw ServerConfigurationError.duplicateKey(line.key)
                }
            }
        }

        return try ServerConfiguration(
            fileValues: fileValues,
            environment: environment
        )
    }

    // swiftlint:disable:nextline
    init(
        fileValues: [String: String],
        environment: [String: String]
    ) throws {
        let knownKeys: Set<String> = [
            "server_ip",
            "server_port",
            "protocol_version",
            "motd",
            "max_players",
            "login_rejection_message",
        ]

        for key in fileValues.keys.sorted() where !knownKeys.contains(key) {
            throw ServerConfigurationError.unknownKey(key)
        }

        func value(_ key: String, default defaultValue: String) -> String {
            environment[key] ?? fileValues[key] ?? defaultValue
        }

        let host = value("server_ip", default: Self.defaultHost)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            throw ServerConfigurationError.invalidValue(
                key: "server_ip",
                value: host
            )
        }

        let portText = value("server_port", default: String(Self.defaultPort))
        guard let port = Int(portText), (1...65_535).contains(port) else {
            throw ServerConfigurationError.invalidValue(
                key: "server_port",
                value: portText
            )
        }

        let protocolVersionText = value(
            "protocol_version",
            default: String(Self.defaultProtocolVersion.rawValue)
        )
        guard let protocolNumber = Int32(protocolVersionText) else {
            throw ServerConfigurationError.invalidValue(
                key: "protocol_version",
                value: protocolVersionText
            )
        }
        guard let protocolVersion = Protocol754(
            rawValue: Int(protocolNumber)
        ) else {
            throw ServerConfigurationError.unsupportedProtocolVersion(
                protocolNumber
            )
        }

        let maxPlayersText = value(
            "max_players",
            default: String(Self.defaultMaxPlayers)
        )
        guard let maxPlayers = Int(maxPlayersText),
                maxPlayers >= 0,
                maxPlayers <= Int(Int32.max) else {
            throw ServerConfigurationError.invalidValue(
                key: "max_players",
                value: maxPlayersText
            )
        }

        self.host = host
        self.port = port
        self.protocolVersion = protocolVersion
        self.motd = value("motd", default: Self.defaultMOTD)
        self.maxPlayers = maxPlayers
        self.loginRejectionMessage = value(
            "login_rejection_message",
            default: Self.defaultLoginRejectionMessage
        )
    }
}
