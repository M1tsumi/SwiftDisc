import Foundation

/// A protocol for creating loadable extension modules ("cogs") for a bot.
///
/// Extensions allow you to organize your bot's functionality into reusable modules.
/// Each extension can register commands, event handlers, and other features when loaded.
///
/// Conforming types must be `Sendable` since they are stored inside the
/// `DiscordClient` actor and dispatched across task boundaries.
///
/// ## Example
///
/// ```swift
/// struct ModerationExtension: SwiftDiscExtension {
///     func onRegister(client: DiscordClient) async {
///         // Register commands, set up event handlers, etc.
///         client.useCommands { commands in
///             commands.command("ban", description: "Ban a user") { ctx in
///                 // Ban logic
///             }
///         }
///     }
///     
///     func onUnload(client: DiscordClient) async {
///         // Clean up resources if needed
///     }
/// }
/// ```
///
/// ## See Also
/// - `DiscordClient.loadExtension(_:)`
/// - `DiscordClient.unloadExtensions()`
/// - `Cog`
public protocol SwiftDiscExtension: Sendable {
    /// Called when the extension is registered with the client.
    ///
    /// Use this method to register commands, set up event handlers, and initialize any state.
    ///
    /// - Parameter client: The `DiscordClient` instance.
    func onRegister(client: DiscordClient) async
    
    /// Called when the extension is unloaded from the client.
    ///
    /// Use this method to clean up resources and remove event handlers.
    ///
    /// - Parameter client: The `DiscordClient` instance.
    func onUnload(client: DiscordClient) async
}

public extension SwiftDiscExtension {
    /// Default implementation for `onRegister` - does nothing.
    func onRegister(client: DiscordClient) async {}
    
    /// Default implementation for `onUnload` - does nothing.
    func onUnload(client: DiscordClient) async {}
}

/// A closure-based implementation of `SwiftDiscExtension`.
///
/// `Cog` provides a convenient way to create extensions using closures instead of
/// creating a new type that conforms to `SwiftDiscExtension`.
///
/// ## Example
///
/// ```swift
/// let moderationCog = Cog(
///     name: "Moderation",
///     onRegister: { client in
///         client.useCommands { commands in
///             commands.command("ban", description: "Ban a user") { ctx in
///                 // Ban logic
///             }
///         }
///     }
/// )
/// try await client.loadExtension(moderationCog)
/// ```
///
/// ## See Also
/// - `SwiftDiscExtension`
/// - `DiscordClient.loadExtension(_:)`
public final class Cog: SwiftDiscExtension, Sendable {
    /// The name of the cog.
    public let name: String
    
    private let registerBlock: @Sendable (DiscordClient) async -> Void
    private let unloadBlock: @Sendable (DiscordClient) async -> Void

    /// Creates a new cog.
    ///
    /// - Parameters:
    ///   - name: The name of the cog.
    ///   - onRegister: A closure called when the cog is registered.
    ///   - onUnload: A closure called when the cog is unloaded (default does nothing).
    public init(
        name: String,
        onRegister: @escaping @Sendable (DiscordClient) async -> Void,
        onUnload: @escaping @Sendable (DiscordClient) async -> Void = { _ in }
    ) {
        self.name = name
        self.registerBlock = onRegister
        self.unloadBlock = onUnload
    }

    public func onRegister(client: DiscordClient) async { await registerBlock(client) }
    public func onUnload(client: DiscordClient) async { await unloadBlock(client) }
}
