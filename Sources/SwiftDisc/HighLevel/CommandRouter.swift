import Foundation

/// Routes prefix-based text commands. Declared as an `actor` so handler
/// registration and dispatch are data-race free across concurrent tasks.
public actor CommandRouter {
    /// The async, Sendable handler type invoked when a command matches.
    public typealias Handler = @Sendable (Context) async throws -> Void

    /// Per-invocation context provided to every command handler.
    public struct Context: Sendable {
        public let client: DiscordClient
        public let message: Message
        public let args: [String]
        public init(client: DiscordClient, message: Message, args: [String]) {
            self.client = client
            self.message = message
            self.args = args
        }
    }

    /// Metadata exposed via `listCommands()`.
    public struct CommandMeta: Sendable {
        public let name: String
        public let description: String
    }

    private var prefix: String
    private var handlers: [String: Handler] = [:]
    private var metadata: [String: CommandMeta] = [:]
    /// Optional error handler invoked when a command handler throws.
    public var onError: (@Sendable (Error, Context) -> Void)?

    public init(prefix: String = "!") {
        self.prefix = prefix
    }

    /// Update the command prefix at runtime.
    public func use(prefix: String) {
        self.prefix = prefix
    }

    /// Register a command name (case-insensitive) with a handler.
    public func register(_ name: String, description: String = "", handler: @escaping Handler) {
        let key = name.lowercased()
        handlers[key] = handler
        metadata[key] = CommandMeta(name: name, description: description)
    }

    /// Check whether a message is a command and dispatch it.
    public func handleIfCommand(message: Message, client: DiscordClient) async {
        guard let content = message.content, !content.isEmpty else { return }
        guard content.hasPrefix(prefix) else { return }
        let noPrefix = String(content.dropFirst(prefix.count))
        let parts = noPrefix.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let cmd = parts.first?.lowercased() else { return }
        let args = Array(parts.dropFirst())
        guard let handler = handlers[cmd] else { return }
        do {
            try await handler(Context(client: client, message: message, args: args))
        } catch {
            let ctx = Context(client: client, message: message, args: args)
            if let onError { onError(error, ctx) }
        }
    }

    /// Return all registered commands sorted alphabetically.
    public func listCommands() -> [CommandMeta] {
        metadata.values.sorted { $0.name < $1.name }
    }

    /// Generate a human-readable help string listing all commands.
    public func helpText(header: String = "Available commands:") -> String {
        let lines = listCommands().map { meta in
            if meta.description.isEmpty { return "\(prefix)\(meta.name)" }
            return "\(prefix)\(meta.name) — \(meta.description)"
        }
        return ([header] + lines).joined(separator: "\n")
    }
}
