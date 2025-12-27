import Foundation

/// A lightweight command framework for SwiftDisc.
/// Provides prefix-based command routing, checks, and cooldowns.
public final class CommandRouter {
    public typealias Handler = (CommandContext) async -> Void
    public typealias Check = (CommandContext) async -> Bool

    public enum CooldownScope {
        case user
        case guild
        case global
    }

    public struct CommandEntry {
        public let name: String
        public let handler: Handler
        public let checks: [Check]
        public let cooldown: TimeInterval?
        public let cooldownScope: CooldownScope

        public init(name: String, handler: @escaping Handler, checks: [Check] = [], cooldown: TimeInterval? = nil, cooldownScope: CooldownScope = .user) {
            self.name = name
            self.handler = handler
            self.checks = checks
            self.cooldown = cooldown
            self.cooldownScope = cooldownScope
        }
    }

    private var prefix: String
    private var commands: [String: CommandEntry] = [:]
    private let cooldownManager = CooldownManager()

    public init(prefix: String = "!") {
        self.prefix = prefix
    }

    /// Register a simple command by name.
    public func register(_ name: String, handler: @escaping Handler) {
        let entry = CommandEntry(name: name.lowercased(), handler: handler)
        commands[name.lowercased()] = entry
    }

    /// Register a command with checks and optional cooldown.
    public func register(_ name: String, checks: [Check] = [], cooldown: TimeInterval? = nil, cooldownScope: CooldownScope = .user, handler: @escaping Handler) {
        let entry = CommandEntry(name: name.lowercased(), handler: handler, checks: checks, cooldown: cooldown, cooldownScope: cooldownScope)
        commands[name.lowercased()] = entry
    }

    /// Unregister a command.
    public func unregister(_ name: String) {
        commands.removeValue(forKey: name.lowercased())
    }

    /// Process an incoming message and run a command if matched.
    /// Runs checks, and enforces cooldowns when configured.
    public func processMessage(_ message: Message) async {
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard content.hasPrefix(prefix) else { return }

        let withoutPrefix = String(content.dropFirst(prefix.count))
        let parts = withoutPrefix.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let namePart = parts.first else { return }
        let name = namePart.lowercased()
        let args = parts.count > 1 ? String(parts[1]) : ""

        guard let entry = commands[name] else { return }

        let ctx = CommandContext(message: message, args: args)

        // Run checks
        for check in entry.checks {
            if !(await check(ctx)) { return }
        }

        // Cooldown enforcement
        if let cd = entry.cooldown {
            let key = cooldownKey(for: entry.cooldownScope, ctx: ctx)
            if cooldownManager.isOnCooldown(command: entry.name, key: key) { return }
            cooldownManager.setCooldown(command: entry.name, key: key, duration: cd)
        }

        await entry.handler(ctx)
    }

    private func cooldownKey(for scope: CooldownScope, ctx: CommandContext) -> String {
        switch scope {
        case .user: return ctx.message.author.id.rawValue
        case .guild: return ctx.message.guild_id?.rawValue ?? ctx.message.author.id.rawValue
        case .global: return "global"
        }
    }
}

/// Context passed to command handlers.
public struct CommandContext {
    public let message: Message
    public let args: String

    public init(message: Message, args: String) {
        self.message = message
        self.args = args
    }

    /// Convenience: reply to the channel the command was invoked in.
    public func reply(_ content: String) async throws {
        _ = try await message.channelId.createMessage(content: content)
    }
}

