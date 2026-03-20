import Foundation

/// Routes application (slash) command interactions. Declared as an `actor` so
/// handler registration and dispatch are data-race free across concurrent tasks.
public actor SlashCommandRouter {
    /// Per-invocation context provided to every slash-command handler.
    public struct Context: Sendable {
        public let client: DiscordClient
        public let interaction: Interaction
        /// The resolved command path (e.g. `"admin ban"` for a subcommand).
        public let path: String
        private let optionMap: [String: String]

        public init(client: DiscordClient, interaction: Interaction) {
            self.client = client
            self.interaction = interaction
            let (p, m) = SlashCommandRouter.computePathAndOptions(from: interaction)
            self.path = p
            self.optionMap = m
        }

        public func option(_ name: String) -> String? { optionMap[name] }
        public func string(_ name: String) -> String? { option(name) }
        public func bool(_ name: String) -> Bool? { option(name).flatMap { Bool($0) } }
        public func int(_ name: String) -> Int? { option(name).flatMap { Int($0) } }
        public func double(_ name: String) -> Double? { option(name).flatMap { Double($0) } }

        // MARK: Resolved option accessors

        /// Resolve a `user` option to the full `User` object from the interaction's resolved map.
        public func user(_ name: String) -> User? {
            guard let rawId = option(name) else { return nil }
            return interaction.data?.resolved?.users?[UserID(rawId)]
        }

        /// Resolve a `channel` option to a `ResolvedChannel` from the interaction's resolved map.
        public func channel(_ name: String) -> Interaction.ResolvedChannel? {
            guard let rawId = option(name) else { return nil }
            return interaction.data?.resolved?.channels?[ChannelID(rawId)]
        }

        /// Resolve a `role` option to a `ResolvedRole` from the interaction's resolved map.
        public func role(_ name: String) -> Interaction.ResolvedRole? {
            guard let rawId = option(name) else { return nil }
            return interaction.data?.resolved?.roles?[RoleID(rawId)]
        }

        /// Resolve an `attachment` option to a `ResolvedAttachment` from the interaction's resolved map.
        public func attachment(_ name: String) -> Interaction.ResolvedAttachment? {
            guard let rawId = option(name) else { return nil }
            return interaction.data?.resolved?.attachments?[AttachmentID(rawId)]
        }

        /// Resolve a `user` option to the guild member (if present in the interaction's resolved map).
        public func member(_ name: String) -> Interaction.ResolvedMember? {
            guard let rawId = option(name) else { return nil }
            return interaction.data?.resolved?.members?[UserID(rawId)]
        }

        // MARK: - Permission helpers

        /// Returns `true` if the invoking member has the given raw permission bit set.
        ///
        /// Uses `interaction.member?.permissions`, which Discord provides in guild
        /// application command interactions. Returns `false` for DMs (no member) or
        /// if the field is absent.
        public func hasPermission(_ bit: UInt64) -> Bool {
            guard let permStr = interaction.member?.permissions,
                  let permInt = UInt64(permStr) else { return false }
            return (permInt & bit) != 0
        }

        /// Returns `true` if the invoking member holds the `ADMINISTRATOR` permission (`1 << 3`).
        public var isAdmin: Bool { hasPermission(1 << 3) }

        /// Returns `true` if the invoking member has the specified role.
        public func memberHasRole(_ roleId: RoleID) -> Bool {
            interaction.member?.roles.contains(roleId) ?? false
        }
    }

    /// The async, Sendable handler type invoked when a slash command matches.
    public typealias Handler = @Sendable (Context) async throws -> Void

    /// Middleware type. A sendable closure that receives the context and a `next`
    /// handler. Call `try await next(ctx)` to continue the chain, or
    /// throw / return early to halt further processing.
    ///
    /// ```swift
    /// router.use { ctx, next in
    ///     guard ctx.isAdmin else {
    ///         try await ctx.client.createInteractionResponse(
    ///             id: ctx.interaction.id,
    ///             token: ctx.interaction.token,
    ///             response: ["type": 4, "data": ["content": "🚫 Admins only.", "flags": 64]]
    ///         )
    ///         return
    ///     }
    ///     try await next(ctx)
    /// }
    /// ```
    public typealias Middleware = @Sendable (Context, @escaping Handler) async throws -> Void

    private var handlers: [String: Handler] = [:]
    private var middlewares: [Middleware] = []
    /// Optional error handler invoked when a command handler throws.
    public var onError: (@Sendable (Error, Context) -> Void)?

    public init() {}

    /// Register a top-level command name.
    public func register(_ name: String, handler: @escaping Handler) {
        handlers[name.lowercased()] = handler
    }

    /// Register using a full path, e.g. `"echo"` or `"admin ban"` or `"admin user info"`.
    public func registerPath(_ path: String, handler: @escaping Handler) {
        handlers[path.lowercased()] = handler
    }

    /// Register a middleware to run before every slash-command handler.
    ///
    /// Middlewares execute in registration order. Each middleware **must** call
    /// `next(ctx)` to proceed to the next middleware (or the final handler).
    public func use(_ middleware: @escaping Middleware) {
        middlewares.append(middleware)
    }

    /// Dispatch an incoming interaction to the matching handler.
    public func handle(interaction: Interaction, client: DiscordClient) async {
        guard let commandName = interaction.data?.name, !commandName.isEmpty else { return }
        let ctx = Context(client: client, interaction: interaction)
        guard let handler = handlers[ctx.path.lowercased()] ?? handlers[commandName.lowercased()] else { return }
        do {
            var chain: Handler = handler
            for mw in middlewares.reversed() {
                let next = chain
                let m = mw
                chain = { @Sendable ctx in try await m(ctx, next) }
            }
            try await chain(ctx)
        } catch { if let onError { onError(error, ctx) } }
    }

    // MARK: - Path and options resolution

    /// Compute the resolved path and option map for an interaction.
    /// Marked `nonisolated` so it can be called without an actor hop from `Context.init`.
    nonisolated static func computePathAndOptions(from interaction: Interaction) -> (String, [String: String]) {
        guard let data = interaction.data else { return ("", [:]) }
        var components: [String] = []
        if let rootName = data.name, !rootName.isEmpty {
            components.append(rootName)
        }
        var cursorOptions = data.options ?? []
        var leafOptions: [Interaction.ApplicationCommandData.Option] = []
        // Drill into subcommand / subcommand-group levels
        while let first = cursorOptions.first, let type = first.type, (type == 1 || type == 2) {
            components.append(first.name)
            cursorOptions = first.options ?? []
        }
        leafOptions = cursorOptions
        var map: [String: String] = [:]
        for opt in leafOptions {
            if let v = opt.value, let s = v.stringValue { map[opt.name] = s }
        }
        return (components.joined(separator: " "), map)
    }
}
