import Foundation
import NIO
import Rainbow
/// A `ChannelInboundHandler` to display `Packet`s.
final class DisplayPacketHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = Packet
    typealias InboundOut = Packet
    /// The `ConnectionContext` for the `DisplayPacketHandler`
    private let connection: ConnectionContext
    /// The `ServerConfiguration` for the `DisplayPacketHandler`
    private let configuration: ServerConfiguration

    // MARK: Initialization
    /// The `DisplayPacketHandler` is initialized with a `ConnectionContext`
    /// - parameter connection: The `ConnectionContext` for the `DisplayPacketHandler`
    init(
        connection: ConnectionContext,
        configuration: ServerConfiguration
    ) {
        self.connection = connection
        self.configuration = configuration
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
                    case Protocol754.Handshake.statusIntention:
                        connection.set(.status)
                    case Protocol754.Handshake.loginIntention:
                        guard packet.version == Int32(configuration.protocolVersion.rawValue) else {
                            logger.info("Rejecting login protocol \(packet.version); ",
                                metadata: ["server supports": "\(configuration.protocolVersion.rawValue)"]
                            )
                            context.close(promise: nil)
                            return
                        }
                        connection.set(.login)
                    default:
                        logger.info("Rejecting unsupported handshake intention \(packet.intention)")
                        context.close(promise: nil)
                        return
                }
            case is StatusRequest:
                do {
                    let info = StatusInfo(configuration: configuration)
                    let data = try JSONEncoder().encode(info)
                    guard let json = String(decoding: data, as: UTF8.self) else {
                        throw EncodingError.invalidValue(
                            info,
                            .init(codingPath: [], debugDescription: "Status JSON is not UTF-8")
                        )
                    }
                    let response = StatusResponse(json: json)
                    send(response, context: context, closeAfterWrite: false)
                } catch {
                    errorCaught(context: context, error: error)
                    return
                }
            case is LoginStart:
                do {
                    let reply = try LoginDisconnect(
                        message: configuration.loginRejectionMessage
                    )
                    send(reply, context: context, closeAfterWrite: true)
                } catch {
                    errorCaught(context: context, error: error)
                }
                return
            case let ping as StatusPing:
                guard let payload = ping.data["payload"] as? Int64 else {
                    errorCaught(
                        context: context,
                        error: PacketFieldError.missing("payload")
                    )
                    return
                }

                send(
                    StatusPong(payload: payload),
                    context: context,
                    closeAfterWrite: true
                )
                return
            default:
                print("Unknown Packet Type: \(type(of: packet))")
        }

        context.fireChannelRead(wrapInboundOut(packet))
    }

    private func send(
        _ packet: Packet,
        context: ChannelHandlerContext,
        closeAfterWrite: Bool
    ) {
        let promise = context.eventLoop.makePromise(of: Void.self)
        let channel = context.channel

        promise.futureResult.whenComplete { result in
            switch result {
            case .success:
                if closeAfterWrite {
                    channel.close(promise: nil)
                }
            case .failure(let error):
                logger.error("Reply failed: \(error)")
                channel.close(promise: nil)
            }
        }

        context.writeAndFlush(wrapInboundOut(packet), promise: promise)
    }
}
