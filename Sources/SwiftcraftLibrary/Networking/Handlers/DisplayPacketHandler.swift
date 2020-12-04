//
//  DisplayPacketHandler.swift
//  
//
//  Created by Marz Rover on 12/3/20.
//

import Foundation
import NIO

class DisplayPacketHandler: ChannelInboundHandler {
    typealias InboundIn = Packet
    typealias InboundOut = Packet

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
                print("Unkown Packet ID")
        }

        context.fireChannelRead(wrapInboundOut(rawPacket))
    }
}
