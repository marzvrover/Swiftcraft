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
        let length: Int32 = try! Int32(buffer: &buffer)
        print("Length: \(length)".blue)
        if (length < 1) {
            debug("packet too small".blue)
        }
        
        let packetID = try! Int32(buffer: &buffer)
        print("Packet ID: \(packetID)".blue)

        let protocolVersion = try! Int32(buffer: &buffer)
        print("Protocol Version: \(protocolVersion)".blue)
        
        let serverAddress = try! String(buffer: &buffer)
        print("Server Address: \(serverAddress)".blue)

        let serverPort = UInt16(buffer: &buffer)
        print("Server Port: \(serverPort)".blue)

        let intention = try! Int32(buffer: &buffer)
        print("Intention: \(intention)".blue)
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
