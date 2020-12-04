//
//  PacketDecoder.swift
//  
//
//  Created by Marz Rover on 12/3/20.
//

import Foundation
import NIO

enum PacketDecoderError: Error {
    case unknownPacketID(Int32)
}

struct PacketDecoder: ByteToMessageDecoder {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = Packet

    mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // 5 bytes is the max length for a VarInt (which tells us our packet length)
        guard buffer.readableBytes >= 5 else {
            return .needMoreData
        }
        let saved = buffer
        do {
            // length of PacketID + Data
            let length = try! buffer.readVarInt()

            guard buffer.readableBytes >= length else {
                return .needMoreData
            }

            var packet: Packet

            let id = try buffer.readVarInt()

            switch id {
                case 0x00:
                    packet = Handshake()
                    break
                default:
                    throw PacketDecoderError.unknownPacketID(id)
            }

            try packet.decode(buffer: &buffer)

            context.fireChannelRead(self.wrapInboundOut(packet))

            return .continue
        } catch {
            buffer = saved
            throw error
        }
    }
}
