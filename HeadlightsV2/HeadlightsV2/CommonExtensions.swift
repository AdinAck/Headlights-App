//
//  CommandExtensions.swift
//  HeadlightsV2
//
//  Created by Adin Ackerman on 12/3/23.
//

import Foundation
import Common

extension Properties {
    init?(from buf: Data) {
        guard let value = deserializeStdProperties(buf: buf) else { return nil }
        self = value
    }
}

extension AppError {
    init?(from buf: Data) {
        guard let value = deserializeStdAppError(buf: buf) else { return nil }
        self = value
    }
}

extension Request {
    func serialize() -> Data {
        serializeStdRequest(cmd: self)
    }
}

extension Status {
    init?(from buf: Data) {
        guard let value = deserializeStdStatus(buf: buf) else { return nil }
        self = value
    }
}

extension Control {
    init?(from buf: Data) {
        guard let value = deserializeStdControl(buf: buf) else { return nil }
        self = value
    }
    
    func serialize() -> Data {
        serializeStdControl(cmd: self)
    }
}

extension Monitor {
    init?(from buf: Data) {
        guard let value = deserializeStdMonitor(buf: buf) else { return nil }
        self = value
    }
}

extension Config {
    init?(from buf: Data) {
        guard let value = deserializeStdConfig(buf: buf) else { return nil }
        self = value
    }
    
    func serialize() -> Data {
        serializeStdConfig(cmd: self)
    }
}

extension Reset {
    func serialize() -> Data {
        serializeStdReset(cmd: self)
    }
}
