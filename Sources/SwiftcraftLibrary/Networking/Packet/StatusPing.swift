import NIO

final class StatusPing: Packet {
    init() {
        super.init(
            id: 0x01,
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
            id: 0x01,
            definition: [
                (name: "payload", type: .long, args: nil)
            ],
            data: ["payload": payload]
        )
    }
}
