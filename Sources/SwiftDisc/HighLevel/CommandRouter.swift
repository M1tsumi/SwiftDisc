//
//  CommandRouter.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public final class CommandRouter {
    public typealias Handler = (Context) async throws -> Void

    public struct Context {
        public let client: DiscordClient
        public let message: Message
        public let args: [String]
        public init(client: DiscordClient, message: Message, args: [String]) {
            self.client = client
            self.message = message
            self.args = args
        }
    }

    public struct CommandMeta: Sendable {
        public let name: String
        public let description: String
    }

    private var prefix: String
    private var handlers: [String: Handler] = [:]
    private var metadata: [String: CommandMeta] = [:]
    public var onError: ((Error, Context) -> Void)?

    public init(prefix: String = "!") {
        self.prefix = prefix
    }

    public func use(prefix: String) {
        self.prefix = prefix
    }

    public func register(_ name: String, description: String = "", handler: @escaping Handler) {
        let key = name.lowercased()
        handlers[key] = handler
        metadata[key] = CommandMeta(name: name, description: description)
    }

    public func handleIfCommand(message: Message, client: DiscordClient) async {
        guard !message.content.isEmpty else { return }
        guard message.content.hasPrefix(prefix) else { return }
        let noPrefix = String(message.content.dropFirst(prefix.count))
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

    public func listCommands() -> [CommandMeta] {
        metadata.values.sorted { $0.name < $1.name }
    }

    public func helpText(header: String = "Available commands:") -> String {
        let lines = listCommands().map { meta in
            if meta.description.isEmpty { return "\(prefix)\(meta.name)" }
            return "\(prefix)\(meta.name) — \(meta.description)"
        }
        return ([header] + lines).joined(separator: "\n")
    }
}
