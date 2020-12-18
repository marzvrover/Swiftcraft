import Foundation
import NIO
/// Errors that may be thrown by `PacketCodec`
enum PacketCodecError {
    /// Errors related to decoding
    enum decode: Error {
        /// Unkown `Packet`.`id`
        case unknownPacketID(Int32)
    }
}
/// The `ByteToMessageDecoder` for decoding `Packets`
struct PacketCodec: ByteToMessageDecoder, MessageToByteEncoder {
    /// The `InboundIn` datatype is a `ByteBuffer`
    typealias InboundIn = ByteBuffer
    /// The `InboundOut` datatype is a `Packet`
    typealias InboundOut = Packet
    /// The `OutboundIn` datatype is a `Packet`
    typealias OutboundIn = Packet
    /// The `OutboundOut` datatype is a `ByteBuffer`
    typealias OutboundOut = ByteBuffer
    // MARK: PacketDecoder
    /// The method to decode the `Packet`
    /// - parameters:
    ///     - context: `ChannelHandlerContext`
    ///     - buffer: `inout` `ByteBuffer`: The `ByteBuffer` to decode
    /// - throws: May throw any `PacketDecoderError`
    /// - returns: `DecodingState`
    mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // TODO: handle 0xFE packet
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
                    if length > 9 {
                        packet = Handshake()
                    } else {
                        logger.error("Unkown Packet ID with length <= 9",
                                     metadata: ["packet id": "\(id)",
                                                "packet length": "\(length)",],
                                     file: #file,
                                     function: #function,
                                     line: #line)
                        throw PacketCodecError.decode.unknownPacketID(id)
                    }
                    break
                default:
                    logger.error("Unkown Packet ID", metadata: ["packet-id": "\(id)"], file: #file, function: #function, line: #line)
                    throw PacketCodecError.decode.unknownPacketID(id)
            }

            try packet.decode(buffer: &buffer)

            context.fireChannelRead(self.wrapInboundOut(packet))

            return .continue
        } catch {
            buffer = saved
            // logger.error("Unexpected Error: \(error)", file: #file, function: #function, line: #line)
            context.fireErrorCaught(error)
            throw error
        }
    }
    // MARK: PacketEncoder
    /// The method to encode the `Packet`
    /// - parameters:
    ///     - data: Out going `Packet`
    ///     - out: `inout` `ByteBuffer`: The `ByteBuffer` to encode on
    func encode(data: OutboundIn, out: inout ByteBuffer) throws {
        data.encode(buffer: &out)
    }
}
