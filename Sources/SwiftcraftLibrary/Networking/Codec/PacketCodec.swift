import Foundation
import NIO
/// Errors that may be thrown by `PacketCodec`
enum PacketCodecError {
    /// Errors related to decoding
    enum Decode: Error {
        /// Unkown `Packet`.`id`
        case unknownPacketID(Int32)
        /// Invalid Frame Length
        case invalidFrameLength(Int32)
        /// Invalid Length Prefix
        case invalidLengthPrefix
        /// incompletePacketID
        case incompletePacketID
        /// trailingPacketData
        case trailingPacketData
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
    /// The `ConnectionContext` for the `PacketCodec`
    private let connection: ConnectionContext
    // MARK: Initialization
    /// The `PacketCodec` is initialized with a `ConnectionContext`
    /// - parameter connection: The `ConnectionContext` for the `PacketCodec`
    init(connection: ConnectionContext) {
        self.connection = connection
    }
    // MARK: PacketDecoder
    /// The method to decode the `Packet`
    /// - parameters:
    ///     - context: `ChannelHandlerContext`
    ///     - buffer: `inout` `ByteBuffer`: The `ByteBuffer` to decode
    /// - throws: May throw any `PacketDecoderError`
    /// - returns: `DecodingState`
    mutating func decode(
        context: ChannelHandlerContext,
        buffer: inout ByteBuffer
    ) throws -> DecodingState {
        var working = buffer
        guard var frame = try readFrame(from: &working) else {
            return .needMoreData
        }
        guard let packetID = try frame.readVarIntIfAvailable() else {
            throw PacketCodecError.Decode.incompletePacketID
        }

        var packet = try makePacket(
            packetID: packetID,
            state: connection.get(),
            frame: frame
        )
        try packet.decode(buffer: &frame)
        guard frame.readableBytes == 0 else {
            throw PacketCodecError.Decode.trailingPacketData
        }

        buffer = working
        context.fireChannelRead(self.wrapInboundOut(packet))
        return .continue
    }

    private func readFrame(from buffer: inout ByteBuffer) throws -> ByteBuffer? {
        let prefixStart = buffer.readerIndex
        guard let length = try buffer.readVarIntIfAvailable() else {
            if buffer.readableBytes >= Protocol754.WireLimits.packetLengthMaximumBytes {
                throw PacketCodecError.Decode.invalidLengthPrefix
            }
            return nil
        }
        guard buffer.readerIndex - prefixStart
                <= Protocol754.WireLimits.packetLengthMaximumBytes else {
            throw PacketCodecError.Decode.invalidLengthPrefix
        }
        guard length > 0 && length <= Protocol754.WireLimits.packetLengthMaximum else {
            throw PacketCodecError.Decode.invalidFrameLength(length)
        }
        return buffer.readSlice(length: Int(length))
    }

    private func makePacket(
        packetID: Int32,
        state: State,
        frame: ByteBuffer
    ) throws -> Packet {
        switch state {
        case .handshaking:
            return try makeHandshakePacket(packetID: packetID)
        case .status:
            return try makeStatusPacket(
                packetID: packetID,
                state: state,
                frame: frame
            )
        case .login:
            return try makeLoginPacket(
                packetID: packetID,
                state: state,
                frame: frame
            )
        case .play:
            throw unknownPacket(
                packetID: packetID,
                state: state,
                frame: frame
            )
        }
    }

    private func makeHandshakePacket(packetID: Int32) throws -> Packet {
        guard packetID == Protocol754.Handshake.serverboundID else {
            throw PacketCodecError.Decode.unknownPacketID(packetID)
        }
        return Handshake()
    }

    private func makeStatusPacket(
        packetID: Int32,
        state: State,
        frame: ByteBuffer
    ) throws -> Packet {
        switch packetID {
        case Protocol754.StatusServerbound.requestID:
            return StatusRequest()
        case Protocol754.StatusServerbound.pingID:
            return StatusPing()
        default:
            throw unknownPacket(
                packetID: packetID,
                state: state,
                frame: frame
            )
        }
    }

    private func makeLoginPacket(
        packetID: Int32,
        state: State,
        frame: ByteBuffer
    ) throws -> Packet {
        guard packetID == Protocol754.LoginServerbound.startID else {
            throw unknownPacket(
                packetID: packetID,
                state: state,
                frame: frame
            )
        }
        return LoginStart()
    }

    private func unknownPacket(
        packetID: Int32,
        state: State,
        frame: ByteBuffer
    ) -> PacketCodecError.Decode {
        logger.error("Unknown Packet ID: \(packetID)", metadata: [
            "id": "\(packetID)",
            "state": "\(state)",
            "frame": "\(frame)",
        ])
        return .unknownPacketID(packetID)
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
