import Foundation

/// Simple cooldown manager keyed by command name + key (user/guild/global).
/// Declared as a `public actor` so concurrent accesses from multiple commands are
/// data-race free without any manual locking. Use it anywhere in your bot code.
public actor CooldownManager {
    private var store: [String: Date] = [:]
    private var cleanupTask: Task<Void, Never>?
    private var autoCleanupInterval: TimeInterval = 300 // 5 minutes default

    public init() {
        // Auto-cleanup started lazily on first access to avoid actor isolation issues in init
    }
    
    deinit {
        cleanupTask?.cancel()
    }

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
    /// Automatically purges expired entries periodically.
    public func setCooldown(command: String, key: String, duration: TimeInterval) {
        let compound = compoundKey(command: command, key: key)
        store[compound] = Date().addingTimeInterval(duration)
        // Trigger cleanup if store is getting large
        if store.count > 1000 {
            purgeExpired()
        }
    }

    /// Clears the cooldown for a specific command + key (e.g. on admin override).
    public func clearCooldown(command: String, key: String) {
        store.removeValue(forKey: compoundKey(command: command, key: key))
    }
    
    /// Clears all cooldowns for a specific command across all keys.
    public func clearCommandCooldowns(command: String) {
        let prefix = "\(command)::"
        store = store.filter { !$0.key.hasPrefix(prefix) }
    }

    /// Removes all expired entries. Called automatically but safe to call manually.
    public func purgeExpired() {
        let now = Date()
        store = store.filter { now < $0.value }
    }
    
    /// Returns the number of active (non-expired) cooldown entries.
    public func activeCount() -> Int {
        purgeExpired()
        return store.count
    }
    
    /// Clears all cooldowns.
    public func clearAll() {
        store.removeAll()
    }
    
    /// Sets the automatic cleanup interval in seconds.
    /// Pass `nil` to disable automatic cleanup.
    public func setAutoCleanupInterval(_ interval: TimeInterval?) {
        cleanupTask?.cancel()
        if let interval = interval {
            autoCleanupInterval = interval
            if cleanupTask == nil {
                startAutoCleanup()
            }
        }
    }

    private func compoundKey(command: String, key: String) -> String {
        return "\(command)::\(key)"
    }
    
    private func startAutoCleanup() {
        cleanupTask = Task { @Sendable in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.autoCleanupInterval * 1_000_000_000))
                self.purgeExpired()
            }
        }
    }
}
