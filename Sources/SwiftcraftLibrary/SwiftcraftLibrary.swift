import Foundation
import Logging

public enum State {
    case handshaking
    case status
    case login
    case play
}

var playerState: State = .handshaking

public let logger = Logger(label: "SwiftcraftLibrary")
