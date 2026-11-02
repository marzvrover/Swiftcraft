import Foundation
import NIO
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
    public func channelRead(
        context: ChannelHandlerContext,
        data: NIOAny
    ) {
        let packet = self.unwrapInboundIn(data)
        logger.trace("Packet ID: \(packet.id)")

        switch packet {
        case let handshake as Handshake:
            guard handle(handshake, context: context) else {
                return
            }
        case is StatusRequest:
            guard handleStatusRequest(context: context) else {
                return
            }
        case is LoginStart:
            handleLoginStart(context: context)
            return
        case let ping as StatusPing:
            handle(ping, context: context)
            return
        default:
            logger.warning("Unknown Packet Type: \(type(of: packet))")
        }

        context.fireChannelRead(wrapInboundOut(packet))
    }

    private func handle(
        _ packet: Handshake,
        context: ChannelHandlerContext
    ) -> Bool {
        logger.debug("Protocol Version: \(packet.version)")
        logger.debug("Server Address: \(packet.address)")
        logger.debug("Server Port: \(packet.port)")
        logger.debug("Intention: \(packet.intention)")

        switch packet.intention {
        case Protocol754.Handshake.statusIntention:
            connection.set(.status)
            return true
        case Protocol754.Handshake.loginIntention:
            guard packet.version == Int32(configuration.protocolVersion.rawValue)
            else {
                logger.info(
                    "Rejecting login protocol \(packet.version); ",
                    metadata: [
                        "server supports":
                            "\(configuration.protocolVersion.rawValue)",
                    ]
                )
                context.close(promise: nil)
                return false
            }
            connection.set(.login)
            return true
        default:
            logger.info(
                "Rejecting unsupported handshake intention \(packet.intention)"
            )
            context.close(promise: nil)
            return false
        }
    }

    private func handleStatusRequest(
        context: ChannelHandlerContext
    ) -> Bool {
        do {
            let info = StatusInfo(configuration: configuration)
            let response = StatusResponse(json: try info.json())
            send(response, context: context, closeAfterWrite: false)
            return true
        } catch {
            errorCaught(context: context, error: error)
            return false
        }
    }

    private func handleLoginStart(context: ChannelHandlerContext) {
        do {
            let reply = try LoginDisconnect(
                message: configuration.loginRejectionMessage
            )
            send(reply, context: context, closeAfterWrite: true)
        } catch {
            errorCaught(context: context, error: error)
        }
    }

    private func handle(_ ping: StatusPing, context: ChannelHandlerContext) {
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
    }

    private func send(
        _ packet: Packet,
        context: ChannelHandlerContext,
        closeAfterWrite: Bool
    ) {
        let promise = context.eventLoop.makePromise(of: Void.self)
        let channel = context.channel

        promise.futureResult.whenComplete({ result in
            switch result {
            case .success:
                if closeAfterWrite {
                    channel.close(promise: nil)
                }
            case .failure(let error):
                logger.error("Reply failed: \(error)")
                channel.close(promise: nil)
            }
        })

        context.writeAndFlush(wrapInboundOut(packet), promise: promise)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Connection failed: \(error)")
        context.close(promise: nil)
    }
}
