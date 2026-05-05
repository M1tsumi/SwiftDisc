import Foundation

/// Routes prefix-based text commands. Declared as an `actor` so handler
/// registration and dispatch are data-race free across concurrent tasks.
public actor CommandRouter {
    private var commands: [String: HandlerWrapper] = [:]
    private var aliases: [String: String] = [:]
    private var middleware: [Middleware] = []
    private var prefix: String

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
    public typealias Middleware = @Sendable (Context, _ next: @Sendable (Context) async throws -> Void) async throws -> Void

    /// Per-invocation context provided to every command handler.
    public struct Context: Sendable {
        public let message: Message
        public let client: DiscordClient
        public let args: [String]
        public let command: String

        public init(message: Message, client: DiscordClient, args: [String], command: String) {
            self.message = message
            self.client = client
            self.args = args
            self.command = command
        }

        /// The channel ID where the command was invoked.
        public var channelId: ChannelID { message.channel_id }

        /// The user who invoked the command.
        public var author: User? { message.author }

        // MARK: - Permission utilities

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
            guard let roles = message.member?.roles else { return false }
            return roles.contains(roleId)
        }
    }

    public init(prefix: String) {
        self.prefix = prefix
    }

    /// Sets the error handler for command failures. Must be called from within the actor.
    public func setErrorHandler(_ handler: @Sendable (Error, Context) -> Void?) {
        onError = handler
    }

    /// Optional error handler invoked when a command handler throws.
    /// Use this to log errors, send error responses, or implement custom error recovery.
    ///
    /// ```swift
    /// router.onError = { error, ctx in
    ///     print("Command '\(ctx.command)' failed: \(error)")
    ///     try? await ctx.client.sendMessage(channelId: ctx.channelId, content: "❌ Command failed")
    /// }
    /// ```
    public var onError: (@Sendable (Error, Context) -> Void)?

    /// Register a command handler with an optional description.
    public func register(name: String, description: String? = nil, _ handler: @escaping Handler) {
        commands[name] = HandlerWrapper(handler: handler, description: description)
    }
    
    /// Register an alias for an existing command.
    /// - Parameters:
    ///   - alias: The alias to register
    ///   - command: The command name this alias points to
    public func registerAlias(alias: String, command: String) {
        aliases[alias] = command
    }
    
    /// Register multiple aliases for an existing command.
    /// - Parameters:
    ///   - aliases: Array of alias names
    ///   - command: The command name these aliases point to
    public func registerAliases(aliases: [String], command: String) {
        for alias in aliases {
            self.aliases[alias] = command
        }
    }
    
    /// Unregister a command by name.
    public func unregister(name: String) {
        commands.removeValue(forKey: name)
        // Also remove any aliases pointing to this command
        aliases = aliases.filter { $0.value != name }
    }
    
    /// Remove a specific alias.
    public func removeAlias(alias: String) {
        aliases.removeValue(forKey: alias)
    }

    /// Add middleware that runs before the command handler.
    public func use(_ middleware: @escaping Middleware) {
        self.middleware.append(middleware)
    }
    
    /// Built-in middleware: require a specific permission bit.
    /// If the user doesn't have the permission, sends an error message and stops execution.
    public static func requirePermission(_ permission: UInt64, errorMessage: String = "🚫 You don't have permission to use this command.") -> Middleware {
        return { ctx, next in
            if ctx.hasPermission(permission) {
                try await next(ctx)
            } else {
                _ = try await ctx.client.sendMessage(
                    channelId: ctx.message.channel_id,
                    content: errorMessage,
                    messageReference: MessageReference(message_id: ctx.message.id, channel_id: ctx.message.channel_id)
                )
            }
        }
    }
    
    /// Built-in middleware: require administrator permission.
    public static func requireAdmin(errorMessage: String = "🚫 Only administrators can use this command.") -> Middleware {
        return requirePermission(PermissionsUtil.administrator, errorMessage: errorMessage)
    }
    
    /// Built-in middleware: require the user to have a specific role.
    public static func requireRole(_ roleId: RoleID, errorMessage: String = "🚫 You don't have the required role to use this command.") -> Middleware {
        return { ctx, next in
            if ctx.memberHasRole(roleId) {
                try await next(ctx)
            } else {
                _ = try await ctx.client.sendMessage(
                    channelId: ctx.message.channel_id,
                    content: errorMessage,
                    messageReference: MessageReference(message_id: ctx.message.id, channel_id: ctx.message.channel_id)
                )
            }
        }
    }
    
    /// Built-in middleware: require the command to be used in a guild (not DMs).
    public static func requireGuild(errorMessage: String = "🚫 This command can only be used in a server.") -> Middleware {
        return { ctx, next in
            if ctx.message.guild_id != nil {
                try await next(ctx)
            } else {
                _ = try await ctx.client.sendMessage(
                    channelId: ctx.message.channel_id,
                    content: errorMessage
                )
            }
        }
    }

    /// Process a message and route it to the appropriate handler if it matches the prefix.
    public func handle(_ message: Message, client: DiscordClient) async {
        guard let content = message.content, content.hasPrefix(prefix) else { return }
        let parts = content.dropFirst(prefix.count).split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard let cmdName = parts.first.map(String.init) else { return }
        let args = parts.count > 1 ? String(parts[1]).split(separator: " ").map(String.init) : []
        
        // Resolve alias if applicable
        let commandName = aliases[cmdName] ?? cmdName
        
        guard let wrapper = commands[commandName] else { return }
        let context = Context(message: message, client: client, args: args, command: commandName)

        do {
            try await executeMiddleware(context, handler: wrapper.handler, at: 0)
        } catch {
            if let onError = onError {
                onError(error, context)
            } else {
                // Default error logging when no custom handler is set
                print("[CommandRouter] Error in command '\(commandName)' in channel \(message.channel_id): \(error)")
            }
        }
    }

    /// List all registered commands and their descriptions.
    public func listCommands() -> [(name: String, description: String?)] {
        return commands.map { (name: $0.key, description: $0.value.description) }
    }
    
    /// List all registered aliases.
    public func listAliases() -> [(alias: String, command: String)] {
        return aliases.map { (alias: $0.key, command: $0.value) }
    }
    
    /// Generate help text for all commands.
    public func generateHelp() -> String {
        let commandList = listCommands().sorted { $0.name < $1.name }
        var output = "**Commands:**\n"
        for cmd in commandList {
            if let desc = cmd.description {
                output += "`\(prefix)\(cmd.name)` - \(desc)\n"
            } else {
                output += "`\(prefix)\(cmd.name)`\n"
            }
        }
        let aliasList = listAliases().sorted { $0.alias < $1.alias }
        if !aliasList.isEmpty {
            output += "\n**Aliases:**\n"
            for alias in aliasList {
                output += "`\(prefix)\(alias.alias)` → `\(prefix)\(alias.command)`\n"
            }
        }
        return output
    }

    private func executeMiddleware(_ context: Context, handler: Handler, at index: Int) async throws {
        if index < middleware.count {
            try await middleware[index](context) { @Sendable ctx in
                try await executeMiddleware(ctx, handler: handler, at: index + 1)
            }
        } else {
            try await handler(context)
        }
    }

    private struct HandlerWrapper: Sendable {
        let handler: Handler
        let description: String?
    }
}
