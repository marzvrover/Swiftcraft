import NIO
import Rainbow

public final class HandshakeHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer

    public func channelActive(context: ChannelHandlerContext) {
        debug("Active connection at \(context.remoteAddress!)")
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        debug("Inactive connection at \(context.remoteAddress!)")
    }
    
    public func channelRegistered(context: ChannelHandlerContext) {
        debug("Registered connection at \(context.remoteAddress!)")
    }
    
    public func channelUnregistered(context: ChannelHandlerContext) {
        debug("Unregistered connection at \(context.remoteAddress!)")
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = self.unwrapInboundIn(data)
        let length: Int32 = try! buffer.readVarInt()
        print("Length: \(length)".blue)
        if (length < 1) {
            debug("packet too small".blue)
        }
        
        let packetID = try! buffer.readVarInt()
        print("Packet ID: \(packetID)".blue)

        var handshake = Handshake(length: length, id: packetID, buffer: context.channel.allocator.buffer(buffer: buffer))

        try! handshake.decode()

//        let protocolVersion = try! buffer.readVarInt()
        print("Protocol Version: \(handshake.version)".blue)

//        let serverAddress = try! buffer.readVarString()!
        print("Server Address: \(handshake.address)".blue)

//        let serverPort = buffer.readUInt16()!
        print("Server Port: \(handshake.port)".blue)

//        let intention = try! buffer.readVarInt()
        print("Intention: \(handshake.intention)".blue)
    }

    // Flush it out. This can make use of gathering writes if multiple buffers are pending
    public func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    
    public func channelWritabilityChanged(context: ChannelHandlerContext) {
        debug("Writability changed at \(context.remoteAddress!)")
    }
    
    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        debug("User \(context.remoteAddress!)")
        debug("Event \(event)")
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)

        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
}
