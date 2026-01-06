//
//  CooldownManager.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Simple cooldown manager keyed by command name + key (user/guild/global).
final class CooldownManager {
    private var store: [String: Date] = [:]
    private let lock = NSLock()

    func isOnCooldown(command: String, key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let compound = compoundKey(command: command, key: key)
        if let until = store[compound] {
            return Date() < until
        }
        return false
    }

    func setCooldown(command: String, key: String, duration: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        let compound = compoundKey(command: command, key: key)
        store[compound] = Date().addingTimeInterval(duration)
    }

    private func compoundKey(command: String, key: String) -> String {
        return "\(command)::\(key)"
    }
}
