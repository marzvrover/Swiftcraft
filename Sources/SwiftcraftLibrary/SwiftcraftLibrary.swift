import Foundation
import Logging

public enum State: Sendable {
    case handshaking
    case status
    case login
    case play
}

final class PlayerState: @unchecked Sendable {
    // All access to the state is protected by this lock.
    private let lock = NSLock()
    private var state = State.handshaking

    func get() -> State {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    func set(_ state: State) {
        lock.lock()
        defer { lock.unlock() }
        self.state = state
    }
}

let playerState = PlayerState()

public let logger = Logger(label: "SwiftcraftLibrary")
