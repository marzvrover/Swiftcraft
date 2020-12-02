//
//  SwiftcraftLibrary.swift
//  Swiftcraft
//
//  Created by Marz Rover on 12/2/20.
//

import Foundation

public func debug(_ object: Any) {
    #if DEBUG
    Swift.print(object)
    #endif
}
