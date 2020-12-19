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
        let packet = self.unwrapInboundIn(data)
        print("Packet ID: \(packet.id)".green)

        switch packet {
            case is Handshake:
                let packet = packet as! Handshake
                print("Protocol Version: \(packet.version)".blue)
                print("Server Address: \(packet.address)".blue)
                print("Server Port: \(packet.port)".blue)
                print("Intention: \(packet.intention)".blue)
                if packet.intention == 1 {
                    playerState = .status
                } else if packet.intention == 2 {
                    playerState = .login
                }
                break
            case is StatusRequest:
                print("Status Packet".blue)
                break
            case is LoginStart:
                let packet = packet as! LoginStart
                print("Name: \(packet.name)".blue)
                break
            default:
                print("Unknown Packet Type: \(type(of: packet))")
        }

        context.fireChannelRead(wrapInboundOut(packet))
    }
}
