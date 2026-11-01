import Foundation

final class LoginDisconnect: Packet {
    init(message: String) throws {
        let data = try JSONEncoder().encode(
            StatusInfo.Description(text: message)
        )
        let json = String(decoding: data, as: UTF8.self)

        super.init(
            id: 0x00,
            definition: [
                (name: "reason", type: .varString, args: nil),
            ],
            data: ["reason": json])
    }
}
