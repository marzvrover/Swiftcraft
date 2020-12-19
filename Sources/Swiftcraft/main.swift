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

var server = Server()

defer {
    server.shutdown()
}

do {
    try server.run()
} catch let error {
    logger.error("Fatal error", metadata: ["error": "\(error)"])
    server.shutdown()
}
