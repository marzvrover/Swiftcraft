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
    /// MARK: Initialization
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
    mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        var working = buffer
        let prefixStart = working.readerIndex

        guard let length = try working.readVarIntIfAvailable() else {
            if working.readableBytes >= 3 {
                throw PacketCodecError.Decode.invalidLengthPrefix
            }
            return .needMoreData
        }

        guard working.readerIndex - prefixStart <= 3 else {
            throw PacketCodecError.Decode.invalidLengthPrefix
        }
        guard length > 0 && length <= 2_097_151 else {
            throw PacketCodecError.Decode.invalidFrameLength(length)
        }
        guard var frame = working.readSlice(length: Int(length)) else {
            return .needMoreData
        }
        guard let id = try frame.readVarIntIfAvailable() else {
            throw PacketCodecError.Decode.incompletePacketID
        }

        var packet: Packet

        packetID: switch id {
            case 0x00:
                let state = connection.get()
                currentState: switch state {
                    case .handshaking:
                        packet = Handshake()
                        break currentState
                    case .login:
                        packet = LoginStart()
                        break currentState
                    case .status:
                        packet = StatusRequest()
                        break currentState
                    default:
                        logger.error("Unkown Packet ID with playerState",
                                        metadata: [
                                        "packet id": "\(id)",
                                        "packet length": "\(length)",
                                        "player state": "\(state)",
                                        ],
                                        file: #file,
                                        function: #function,
                                        line: #line)
                        throw PacketCodecError.Decode.unknownPacketID(id)
                }
                break packetID
            default:
                logger.error("Unkown Packet ID",
                                metadata: ["packet-id": "\(id)"],
                                file: #file,
                                function: #function,
                                line: #line)
                throw PacketCodecError.Decode.unknownPacketID(id)
        }

        try packet.decode(buffer: &frame)
        guard frame.readableBytes == 0 else {
            throw PacketCodecError.Decode.trailingPacketData
        }

        buffer = working
        context.fireChannelRead(self.wrapInboundOut(packet))
        return .continue
    }
    // MARK: PacketEncoder
    /// The method to encode the `Packet`
    /// - parameters:
    ///     - data: Out going `Packet`
    ///     - out: `inout` `ByteBuffer`: The `ByteBuffer` to encode on
    func encode(data: OutboundIn, out: inout ByteBuffer) throws {
        data.encode(buffer: &out)
    }

    // MARK: Error Handling
    /// Called when an error occurs
    /// - parameters:
    ///     - context: `ChannelHandlerContext`
    ///     - error: `Error`
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Connection failed: \(error)", file: #file, function: #function, line: #line)
        context.close(promise: nil)
    }
}
