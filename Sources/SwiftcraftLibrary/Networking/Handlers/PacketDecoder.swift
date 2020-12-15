import Foundation
import NIO
/// Errors that may be thrown by `PacketDecoder`
enum PacketDecoderError: Error {
    /// Unkown `Packet`.`id`
    case unknownPacketID(Int32)
}
/// The `ByteToMessageDecoder` for decoding `Packets`
struct PacketDecoder: ByteToMessageDecoder {
    /// The `InboundIn` datatype is a `ByteBuffer`
    typealias InboundIn = ByteBuffer
    /// The `InboundOut` datatype is a `Packet`
    typealias InboundOut = Packet
    /// The method to decode the `Packet`
    /// - parameters:
    ///     - context: `ChannelHandlerContext`
    ///     - buffer: `inout` `ByteBuffer`: The `ByteBuffer` to decode
    /// - throws: May throw any `PacketDecoderError`
    /// - returns: `DecodingState`
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
                    if (length > 9) {
                        packet = Handshake()
                    } else {
                        logger.debug("Packet length < 9", metadata: ["packet length": "\(length)"])
                        throw PacketDecoderError.unknownPacketID(id)
                    }
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
