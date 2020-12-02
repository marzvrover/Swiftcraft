import Foundation
import NIO
import SwiftcraftLibrary
import Rainbow

//  seed linux random number
#if os(Linux)
srand(UInt(time(nil)))
#endif

signal(SIGINT) {_ in
    if (server.isRunning == true) {
        server.shutdown()
    }
    exit(0)
}

print("Welcome to Swiftcraft!".green)

let host = "127.0.0.1"
let port = 25564

var server = Server(host: host, port: port)

defer {
    server.shutdown()
}

do {
    try server.run()
} catch let error {
    print(error)
    print("Shutting down server due to fatal error")
    server.shutdown()
}

print("Server closed")
