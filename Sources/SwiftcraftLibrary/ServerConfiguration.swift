import Foundation
import DotEnv

enum ServerConfigurationError: Error, Equatable {
    case duplicateKey(String)
    case unknownKey(String)
    case invalidValue(key: String, value: String)
    case unsupportedProtocolVersion(Int32)
}

public struct ServerConfiguration: Sendable, Equatable {
    private struct ParsedValues {
        let host: String
        let port: Int
        let protocolVersion: Protocol754
        let motd: String
        let maxPlayers: Int
        let loginRejectionMessage: String
    }

    public static let swiftcraftVersion = "0.0.1"
    public static let defaultHost = "127.0.0.1"
    public static let defaultPort = 25565
    public static let defaultProtocolVersion: Protocol754 = .v754
    public static let defaultMOTD = "Swiftcraft v\(swiftcraftVersion)"
    public static let defaultMaxPlayers = 255
    public static let defaultLoginRejectionMessage =
        "Swiftcraft gameplay is not implemented yet."

    private static let knownKeys: Set<String> = [
        "server_ip",
        "server_port",
        "protocol_version",
        "motd",
        "max_players",
        "login_rejection_message",
    ]

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

    init(
        fileValues: [String: String],
        environment: [String: String]
    ) throws {
        for key in fileValues.keys.sorted()
            where !Self.knownKeys.contains(key) {
            throw ServerConfigurationError.unknownKey(key)
        }

        let values = try Self.parseValues(
            fileValues: fileValues,
            environment: environment
        )
        self.host = values.host
        self.port = values.port
        self.protocolVersion = values.protocolVersion
        self.motd = values.motd
        self.maxPlayers = values.maxPlayers
        self.loginRejectionMessage = values.loginRejectionMessage
        try Self.validateStatusResponseLength(for: self)
        try Self.validateLoginRejectionLength(for: self)
    }

    private static func parseValues(
        fileValues: [String: String],
        environment: [String: String]
    ) throws -> ParsedValues {
        let value = { (key: String, defaultValue: String) in
            environment[key] ?? fileValues[key] ?? defaultValue
        }
        let host = try parseHost(value("server_ip", defaultHost))
        let port = try parsePort(value("server_port", String(defaultPort)))
        let protocolVersion = try parseProtocolVersion(
            value("protocol_version", String(defaultProtocolVersion.rawValue))
        )
        let maxPlayers = try parseMaxPlayers(
            value("max_players", String(defaultMaxPlayers))
        )
        return ParsedValues(
            host: host,
            port: port,
            protocolVersion: protocolVersion,
            motd: value("motd", defaultMOTD),
            maxPlayers: maxPlayers,
            loginRejectionMessage: value(
                "login_rejection_message",
                defaultLoginRejectionMessage
            )
        )
    }

    private static func parseHost(_ value: String) throws -> String {
        let host = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            throw ServerConfigurationError.invalidValue(
                key: "server_ip",
                value: host
            )
        }
        return host
    }

    private static func parsePort(_ value: String) throws -> Int {
        guard let port = Int(value), (1...65_535).contains(port) else {
            throw ServerConfigurationError.invalidValue(
                key: "server_port",
                value: value
            )
        }
        return port
    }

    private static func parseProtocolVersion(_ value: String) throws
        -> Protocol754 {
        guard let protocolNumber = Int32(value) else {
            throw ServerConfigurationError.invalidValue(
                key: "protocol_version",
                value: value
            )
        }
        guard let protocolVersion = Protocol754(rawValue: Int(protocolNumber)) else {
            throw ServerConfigurationError.unsupportedProtocolVersion(
                protocolNumber
            )
        }
        return protocolVersion
    }

    private static func parseMaxPlayers(_ value: String) throws -> Int {
        guard let maxPlayers = Int(value),
                maxPlayers >= 0,
                maxPlayers <= Int(Int32.max) else {
            throw ServerConfigurationError.invalidValue(
                key: "max_players",
                value: value
            )
        }
        return maxPlayers
    }

    private static func validateStatusResponseLength(
        for configuration: ServerConfiguration
    ) throws {
        let json = try StatusInfo(configuration: configuration).json()
        guard json.utf16.count <= Protocol754.WireLimits.stringMaximumCharacters
        else {
            throw ServerConfigurationError.invalidValue(
                key: "motd",
                value: configuration.motd
            )
        }
    }

    private static func validateLoginRejectionLength(
        for configuration: ServerConfiguration
    ) throws {
        let json = try LoginDisconnect.reasonJSON(
            message: configuration.loginRejectionMessage
        )
        let byteCount = json.utf8.count
        let frameLength = 1 + varIntByteCount(byteCount) + byteCount
        guard json.utf16.count
                <= Protocol754.WireLimits.stringMaximumCharacters,
              byteCount <= Protocol754.WireLimits.stringMaximumBytes,
              frameLength <= Protocol754.WireLimits.packetLengthMaximum else {
            throw ServerConfigurationError.invalidValue(
                key: "login_rejection_message",
                value: configuration.loginRejectionMessage
            )
        }
    }

    private static func varIntByteCount(_ value: Int) -> Int {
        var remaining = value
        var byteCount = 1
        while remaining >= 0x80 {
            remaining >>= 7
            byteCount += 1
        }
        return byteCount
    }
}
