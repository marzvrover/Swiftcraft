//
//  File.swift
//  
//
//  Created by Marz Rover on 12/3/20.
//

import Foundation
import NIO

struct Handshake: Packet {
    var length: Int32
    var id: Int32
    var buffer: ByteBuffer
    var data: [String : Any] = [:]
    var definition: [(name: String, type: PacketData, args: [String:Any]?)] = [
        (name: "protocol_version", type: .varInt, args: nil),
        (name: "server_address", type: .varString, args: nil),
        (name: "server_port", type: .unsignedShort, args: nil),
        (name: "intention", type: .varInt, args: nil),
    ]

    var version: Int32 {
        get {
            return self.data["protocol_version"] as! Int32
        }
        set(value) {
            self.data["protocol_version"] = value
        }
    }

    var address: String {
        get {
            return self.data["server_address"] as! String
        }
        set(value) {
            self.data["server_address"] = value
        }
    }

    var port: UInt16 {
        get {
            return self.data["server_port"] as! UInt16
        }
        set(value) {
            self.data["server_port"] = value
        }
    }

    var intention: Int32 {
        get {
            return self.data["intention"] as! Int32
        }
        set(value) {
            self.data["intention"] = value
        }
    }
}
