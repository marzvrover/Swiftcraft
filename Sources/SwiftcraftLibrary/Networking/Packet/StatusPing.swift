import NIO

final class StatusPing: Packet {
    init() {
        super.init(
            id: Protocol754.StatusServerbound.pingID,
            definition: [
                (name: "payload", type: .long, args: nil)
            ],
            data: [:]
        )
    }
}

final class StatusPong: Packet {
    init(payload: Int64) {
        super.init(
            id: Protocol754.StatusClientbound.pongID,
            definition: [
                (name: "payload", type: .long, args: nil)
            ],
            data: ["payload": payload]
        )
    }
}
