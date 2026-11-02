import Foundation

final class LoginDisconnect: Packet {
    init(message: String) throws {
        let description = StatusInfo.Description(text: message)
        let data = try JSONEncoder().encode(description)
        guard let json = String(bytes: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                description,
                .init(codingPath: [], debugDescription: "Status JSON is not UTF-8")
            )
        }

        super.init(
            id: Protocol754.LoginClientbound.disconnectID,
            definition: [
                (name: "reason", type: .varString, args: nil),
            ],
            data: ["reason": json])
    }
}
