import Foundation

/// A minimal Cog/Extension protocol for organizing bot features.
public protocol Cog {
    /// A unique name for the cog.
    var name: String { get }

    /// Called when the cog is loaded into a client.
    func onLoad(client: DiscordClient) async throws

    /// Called when the cog is unloaded from a client.
    func onUnload(client: DiscordClient) async throws
}

public extension Cog {
    func onLoad(client: DiscordClient) async throws {}
    func onUnload(client: DiscordClient) async throws {}
}

/// Manages loading and unloading of `Cog`s.
public final class ExtensionManager {
    private var loaded: [String: Cog] = [:]

    public init() {}

    /// Load a cog into the given client.
    public func load(_ cog: Cog, client: DiscordClient) async throws {
        try await cog.onLoad(client: client)
        loaded[cog.name] = cog
    }

    /// Unload a cog by name.
    public func unload(_ name: String, client: DiscordClient) async throws {
        guard let cog = loaded.removeValue(forKey: name) else { return }
        try await cog.onUnload(client: client)
    }

    /// List loaded cog names.
    public func list() -> [String] {
        return Array(loaded.keys)
    }
}
