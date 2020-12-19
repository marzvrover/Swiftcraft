import Foundation
import NIO
import DotEnv

/// Server class
open class Server {
    /// `true` if the server is running else `false`.
    public var isRunning: Bool
    /// Host the server binds to.
    public var host: String
    /// Port the server binds to.
    public var port: Int
    /// SwiftNIO `Channel` for the server to use.
    public var channel: Channel?
    /// `EventLoopGroup` for the server to use. Uses `System`.`coreCount`
    public let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    /// The `ServerBootstrap` to bind.
    public var bootstrap: ServerBootstrap {
        ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are appled to the accepted Channels
            .childChannelInitializer { channel in
                // Ensure we don't read faster than we can write by adding the BackPressureHandler into the pipeline.
                channel.pipeline.addHandlers([ByteToMessageHandler(PacketCodec()), MessageToByteHandler(PacketCodec())], position: .first).flatMap { _ in
                    channel.pipeline.addHandler(DisplayPacketHandler())
                }
            }

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
    }
    /// To instantiate the server you provide the host and path
    public init(host: String? = nil, port: Int? = nil) {
        self.isRunning = false
        DotEnv.load(path: "server.properties")
        if host != nil {
            self.host = host!
        } else {
            self.host = ProcessInfo.processInfo.environment["server-ip"] ?? "127.0.0.1"
        }
        if port != nil {
            self.port = port!
        } else if ProcessInfo.processInfo.environment["server-port"] == nil {
            self.port = 25565
        } else {
            self.port = Int(ProcessInfo.processInfo.environment["server-port"]!)!
        }
    }
    /// You start the server with the `run()` method.
    /// This binds the `Server`.`bootstrap` to the `Server`.`host` and `Server`.`port`.
    public func run() throws {
        self.isRunning = true
        self.channel = try { () -> Channel in
            return try self.bootstrap.bind(host: self.host, port: self.port).wait()
        }()

        logger.info("Server started and listening on \(channel!.localAddress!)")

        // This will never unblock as we don't close the ServerChannel
        try channel!.closeFuture.wait()
    }
    /// To shutdown the server you call the `Server`.`shutdown()` method.
    /// This attempts to shutdown gracefully but will exit with an error code if an error is thrown.
    public func shutdown() {
        do {
            try self.group.syncShutdownGracefully()
        } catch let error {
            logger.error("Fatal Error", metadata: ["error": "\(error)"])
            exit(1)
        }
        self.isRunning = false
        logger.info("Server Shutdown")
    }
}
