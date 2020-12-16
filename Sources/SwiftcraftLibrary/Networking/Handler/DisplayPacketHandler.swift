import Foundation
import NIO
import Rainbow
/// A `ChannelInboundHandler` to display `Packet`s.
class DisplayPacketHandler: ChannelInboundHandler {
    typealias InboundIn = Packet
    typealias InboundOut = Packet
    /// Channel Read
    /// - parameters:
    ///     - context: `ChannelHandlerContext`
    ///     - data: `NIOAny` which can be unwrapped to have a `Packet`
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let rawPacket = self.unwrapInboundIn(data)
        print("Packet ID: \(rawPacket.id)".blue)

        switch rawPacket.id {
            case 0x00:
                let packet = rawPacket as! Handshake
                print("Protocol Version: \(packet.version)".blue)
                print("Server Address: \(packet.address)".blue)
                print("Server Port: \(packet.port)".blue)
                print("Intention: \(packet.intention)".blue)
                break
            default:
                print("Unkown Packet ID".red)
        }

        context.fireChannelRead(wrapInboundOut(rawPacket))
    }
}
