import Foundation
import NIO
import Rainbow
/// A `ChannelInboundHandler` to display `Packet`s.
final class DisplayPacketHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = Packet
    typealias InboundOut = Packet
    /// The `ConnectionContext` for the `DisplayPacketHandler`
    private let connection: ConnectionContext

    /// MARK: Initialization
    /// The `DisplayPacketHandler` is initialized with a `ConnectionContext`
    /// - parameter connection: The `ConnectionContext` for the `DisplayPacketHandler`
    init(connection: ConnectionContext) {
        self.connection = connection
    }

    /// Channel Read
    /// - parameters:
    ///     - context: `ChannelHandlerContext`
    ///     - data: `NIOAny` which can be unwrapped to have a `Packet`
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = self.unwrapInboundIn(data)
        print("Packet ID: \(packet.id)".green)

        switch packet {
            case is Handshake:
                // swiftlint:disable:next force_cast
                let packet = packet as! Handshake
                print("Protocol Version: \(packet.version)".blue)
                print("Server Address: \(packet.address)".blue)
                print("Server Port: \(packet.port)".blue)
                print("Intention: \(packet.intention)".blue)
                switch packet.intention {
                    case 1:
                        connection.set(.status)
                    case 2:
                        connection.set(.login)
                    default:
                        logger.error("Unsupported Handshake Intention: \(packet.intention)")
                        context.close(promise: nil)
                        return
                }
            case is StatusRequest:
                let info = StatusInfo(
                    version: .init(name: "1.16.5", protocol: 754),
                    players: .init(max: 8, online: 0),
                    description: .init(text: "hello, world: Swiftcraft is learning to talk.")
                )

                do {
                    let data = try JSONEncoder().encode(info)
                    let json = String(decoding: data, as: UTF8.self)
                    let response = StatusResponse(json: json)

                    context.writeAndFlush(
                        wrapInboundOut(response),
                        promise: nil
                    )
                } catch {
                    errorCaught(context: context, error: error)
                    return
                }
            case is LoginStart:
                // swiftlint:disable:next force_cast
                let packet = packet as! LoginStart
                print("Name: \(packet.name)".blue)
            default:
                print("Unknown Packet Type: \(type(of: packet))")
        }

        context.fireChannelRead(wrapInboundOut(packet))
    }
}
