import Foundation

/// Adopt this protocol to create loadable extension modules ("cogs") for a bot.
/// Conforming types must be `Sendable` since they are stored inside the
/// `DiscordClient` actor and dispatched across task boundaries.
public protocol SwiftDiscExtension: Sendable {
    func onRegister(client: DiscordClient) async
    func onUnload(client: DiscordClient) async
}

public extension SwiftDiscExtension {
    func onRegister(client: DiscordClient) async {}
    func onUnload(client: DiscordClient) async {}
}

/// A closure-based implementation of `SwiftDiscExtension`.
public final class Cog: SwiftDiscExtension {
    public let name: String
    private let registerBlock: @Sendable (DiscordClient) async -> Void
    private let unloadBlock: @Sendable (DiscordClient) async -> Void

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
