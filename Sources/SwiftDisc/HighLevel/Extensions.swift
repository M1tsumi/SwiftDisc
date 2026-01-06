//
//  Extensions.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public protocol SwiftDiscExtension {
    func onRegister(client: DiscordClient) async
    func onUnload(client: DiscordClient) async
}

public extension SwiftDiscExtension {
    func onRegister(client: DiscordClient) async {}
    func onUnload(client: DiscordClient) async {}
}

public final class Cog: SwiftDiscExtension {
    public let name: String
    private let registerBlock: (DiscordClient) async -> Void
    private let unloadBlock: (DiscordClient) async -> Void
    public init(name: String, onRegister: @escaping (DiscordClient) async -> Void, onUnload: @escaping (DiscordClient) async -> Void = { _ in }) {
        self.name = name
        self.registerBlock = onRegister
        self.unloadBlock = onUnload
    }
    public func onRegister(client: DiscordClient) async { await registerBlock(client) }
    public func onUnload(client: DiscordClient) async { await unloadBlock(client) }
}
