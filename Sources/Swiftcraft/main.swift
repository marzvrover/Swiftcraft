import Foundation
import Logging
import NIO
import SwiftcraftLibrary

//  seed linux random number
#if os(Linux)
srand(UInt32(time(nil)))
#endif

signal(SIGINT) {_ in
    if server.isRunning == true {
        server.shutdown()
    }
    exit(0)
}

let logger = Logger(label: "Swiftcraft")

logger.info("Welcome to Swiftcraft!")

let configuration: ServerConfiguration
do {
    configuration = try ServerConfiguration.load()
} catch {
    logger.error(
        "Failed to load configuration",
        metadata: ["error": "\(error)"]
    )
    exit(1)
}

var server = Server(configuration: configuration)

signal(SIGINT) {_ in
    if server.isRunning == true {
        server.shutdown()
    }
    exit(0)
}

defer {
    server.shutdown()
}

do {
    try server.run()
} catch let error {
    logger.error("Fatal error", metadata: ["error": "\(error)"])
    server.shutdown()
}
