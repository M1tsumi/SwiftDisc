import Foundation

/// Simple cooldown manager keyed by command name + key (user/guild/global).
/// Declared as a `public actor` so concurrent accesses from multiple commands are
/// data-race free without any manual locking. Use it anywhere in your bot code.
public actor CooldownManager {
    private var store: [String: Date] = []

    public init() {}

    /// Returns `true` if the given command + key combination is still on cooldown.
    public func isOnCooldown(command: String, key: String) -> Bool {
        let compound = compoundKey(command: command, key: key)
        if let until = store[compound] {
            return Date() < until
        }
        return false
    }

    /// Returns the remaining cooldown seconds, or `nil` if not on cooldown.
    public func remaining(command: String, key: String) -> TimeInterval? {
        let compound = compoundKey(command: command, key: key)
        guard let until = store[compound] else { return nil }
        let remaining = until.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    /// Sets a cooldown for `duration` seconds on the given command + key.
    public func setCooldown(command: String, key: String, duration: TimeInterval) {
        let compound = compoundKey(command: command, key: key)
        store[compound] = Date().addingTimeInterval(duration)
    }

    /// Clears the cooldown for a specific command + key (e.g. on admin override).
    public func clearCooldown(command: String, key: String) {
        store.removeValue(forKey: compoundKey(command: command, key: key))
    }

    /// Removes all expired entries. Called automatically but safe to call manually.
    public func purgeExpired() {
        let now = Date()
        store = store.filter { now < $0.value }
    }

    private func compoundKey(command: String, key: String) -> String {
        return "\(command)::\(key)"
    }
}
