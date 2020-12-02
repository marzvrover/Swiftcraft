import NIO

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
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        // context.write(data, promise: nil)
        /// The last three bytes of the handshake buffer are used for an Unsigned Short and a VarInt [source](https://wiki.vg/Protocol#Handshake)
        /// Up to 1023 bytes before the last three are used for String (255) preceded with a VarInt of how many bytes
        /// The first set of bytes is a VarInt
        var byteBuffer = self.unwrapInboundIn(data)
        try! print(Int32(buffer: &byteBuffer))
        try! print(String(buffer: &byteBuffer))

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
