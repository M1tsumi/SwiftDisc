import Foundation

/// Routes prefix-based text commands. Declared as an `actor` so handler
/// registration and dispatch are data-race free across concurrent tasks.
public actor CommandRouter {
    /// The async, Sendable handler type invoked when a command matches.
    public typealias Handler = @Sendable (Context) async throws -> Void

    /// Middleware type. A sendable closure that receives the context and a `next`
    /// handler. Call `try await next(ctx)` to continue the chain, or
    /// throw / return early to halt further processing.
    ///
    /// ```swift
    /// router.use { ctx, next in
    ///     guard ctx.isAdmin else {
    ///         try await ctx.message.reply(client: ctx.client, content: "🚫 Admins only.")
    ///         return
    ///     }
    ///     try await next(ctx)
    /// }
    /// ```
    public typealias Middleware = @Sendable (Context, @escaping Handler) async throws -> Void

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

        // MARK: - Permission helpers

        /// Returns `true` if the message author has the given raw permission bit set.
        ///
        /// Uses `member.permissions`, which Discord provides in guild message events.
        /// Returns `false` for DMs (no member attached) or if the field is absent.
        public func hasPermission(_ bit: UInt64) -> Bool {
            guard let permStr = message.member?.permissions,
                  let permInt = UInt64(permStr) else { return false }
            return (permInt & bit) != 0
        }

        /// Returns `true` if the member holds the `ADMINISTRATOR` permission (`1 << 3`).
        ///
        /// Administrators bypass all channel-level permission overwrites.
        public var isAdmin: Bool { hasPermission(1 << 3) }

        /// Returns `true` if the member has the specified role.
        public func memberHasRole(_ roleId: RoleID) -> Bool {
            message.member?.roles.contains(roleId) ?? false
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
    private var middlewares: [Middleware] = []
    /// Optional error handler invoked when a command handler throws.
    public var onError: (@Sendable (Error, Context) -> Void)?

    public init(prefix: String = "!") {
        self.prefix = prefix
    }

    /// Update the command prefix at runtime.
    public func use(prefix: String) {
        self.prefix = prefix
    }

    /// Register a middleware to run before every command handler.
    ///
    /// Middlewares execute in registration order. Each middleware **must** call
    /// `next(ctx)` to proceed to the next middleware (or the final handler).
    /// Omitting the call acts as an early-exit / guard.
    public func use(_ middleware: @escaping Middleware) {
        middlewares.append(middleware)
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
        let ctx = Context(client: client, message: message, args: args)
        do {
            // Build the middleware chain from back to front so the first registered
            // middleware is the outermost wrapper.
            var chain: Handler = handler
            for mw in middlewares.reversed() {
                let next = chain
                let m = mw
                chain = { @Sendable ctx in try await m(ctx, next) }
            }
            try await chain(ctx)
        } catch {
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
