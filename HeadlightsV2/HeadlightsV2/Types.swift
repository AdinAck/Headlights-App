//
//  Types.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 10/1/23.
//

import Foundation

enum HeadlightRequest: UInt8 {
    case status     = 0x1f
    case brightness = 0xaa
    case monitor    = 0xab
    case pid        = 0xac
}

enum HeadlightState: UInt8 {
    case idle       = 0xf0
    case running    = 0xf1
    case throttling = 0xf2
    case fault      = 0xf3
}

enum HeadlightError: UInt8 {
    case none = 0x00
}

struct HeadlightStatusPacket {
    let state: HeadlightState
    let error: HeadlightError
    
    init?(from data: Data) {
        guard data.count >= MemoryLayout<Self>.size else { return nil }
        
        let (state, error) = data.withUnsafeBytes { raw_ptr in
            (
                HeadlightState(rawValue: raw_ptr.load(fromByteOffset: 0, as: UInt8.self)),
                HeadlightError(rawValue: raw_ptr.load(fromByteOffset: 1, as: UInt8.self))
            )
        }
        
        guard let state else { return nil }
        guard let error else { return nil }
        
        self.state = state
        self.error = error
    }
}

struct HeadlightBrightnessPacket {
    let brightness: UInt8
    
    init?(from data: Data) {
        guard data.count >= MemoryLayout<Self>.size else { return nil }
        
        let brightness = data.withUnsafeBytes { raw_ptr in
            raw_ptr.load(as: UInt8.self)
        }
        
        self.brightness = brightness
    }
}

struct HeadlightMonitorPacket {
    let duty: UInt8
    let current: UInt8
    let temperature: UInt8
    
    init?(from data: Data) {
        guard data.count >= MemoryLayout<Self>.size else { return nil }
        
        (duty, current, temperature) = data.withUnsafeBytes { raw_ptr in
            (
                raw_ptr.load(fromByteOffset: 0, as: UInt8.self),
                raw_ptr.load(fromByteOffset: 1, as: UInt8.self),
                raw_ptr.load(fromByteOffset: 2, as: UInt8.self)
            )
        }
    }
}

struct HeadlightPIDPacket {
    let k_p: UInt8
    let k_i: UInt8
    let k_d: UInt8
    let div: UInt8
    
    init?(from data: Data) {
        guard data.count >= MemoryLayout<Self>.size else { return nil }
        
        (k_p, k_i, k_d, div) = data.withUnsafeBytes { raw_ptr in
            (
                raw_ptr.load(fromByteOffset: 0, as: UInt8.self),
                raw_ptr.load(fromByteOffset: 1, as: UInt8.self),
                raw_ptr.load(fromByteOffset: 2, as: UInt8.self),
                raw_ptr.load(fromByteOffset: 3, as: UInt8.self)
            )
        }
    }
}
