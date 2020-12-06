//
//  Server.swift
//  Swiftcraft
//
//  Created by Marz Rover on 11/17/20.
//

import Foundation
import NIO

open class Server {
    public var isRunning: Bool
    public var host: String
    public var port: Int
    public var channel: Channel?
    
    public let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    
    public var bootstrap: ServerBootstrap {
        ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are appled to the accepted Channels
            .childChannelInitializer { channel in
                // Ensure we don't read faster than we can write by adding the BackPressureHandler into the pipeline.
                channel.pipeline.addHandler(ByteToMessageHandler(PacketDecoder())).flatMap { v in
                    channel.pipeline.addHandler(DisplayPacketHandler())
                }
            }

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
    }
    
    public init(host: String, port: Int) {
        self.isRunning = true
        self.host = host
        self.port = port
    }
    
    public func run() throws {
        self.channel = try { () -> Channel in
            return try self.bootstrap.bind(host: self.host, port: self.port).wait()
        }()

        logger.info("Server started and listening on \(channel!.localAddress!)")

        // This will never unblock as we don't close the ServerChannel
        try channel!.closeFuture.wait()
    }
    
    public func shutdown() {
        do {
            try self.group.syncShutdownGracefully()
        } catch let error {
            logger.error("Fatal Error", metadata: ["error": "\(error)"])
            exit(1)
        }
        logger.info("Server Shutdown")
    }
}
