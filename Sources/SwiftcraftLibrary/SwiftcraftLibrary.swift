//
//  SwiftcraftLibrary.swift
//  Swiftcraft
//
//  Created by Marz Rover on 12/2/20.
//

import Foundation
import Logging

public enum State: Int8 {
    case status = 1
    case login = 2
    case play = 3
}

var playerState: State = .status

public let logger = Logger(label: "SwiftcraftLibrary")