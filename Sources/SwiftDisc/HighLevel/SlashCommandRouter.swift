//
//  SlashCommandRouter.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public final class SlashCommandRouter {
    public struct Context {
        public let client: DiscordClient
        public let interaction: Interaction
        public let path: String
        private let optionMap: [String: String]
        public init(client: DiscordClient, interaction: Interaction) {
            self.client = client
            self.interaction = interaction
            let (p, m) = SlashCommandRouter.computePathAndOptions(from: interaction)
            self.path = p
            self.optionMap = m
        }
        public func option(_ name: String) -> String? {
            optionMap[name]
        }
        public func string(_ name: String) -> String? { option(name) }
        public func bool(_ name: String) -> Bool? { option(name).flatMap { Bool($0) } }
        public func int(_ name: String) -> Int? { option(name).flatMap { Int($0) } }
        public func double(_ name: String) -> Double? { option(name).flatMap { Double($0) } }
    }

    public typealias Handler = (Context) async throws -> Void

    private var handlers: [String: Handler] = [:]
    public var onError: ((Error, Context) -> Void)?

    public init() {}

    public func register(_ name: String, handler: @escaping Handler) {
        handlers[name.lowercased()] = handler
    }

    // Register using full path, e.g. "echo" or "admin ban" or "admin user info"
    public func registerPath(_ path: String, handler: @escaping Handler) {
        handlers[path.lowercased()] = handler
    }

    public func handle(interaction: Interaction, client: DiscordClient) async {
        guard interaction.data?.name.isEmpty == false else { return }
        let ctx = Context(client: client, interaction: interaction)
        guard let handler = handlers[ctx.path.lowercased()] ?? handlers[interaction.data!.name.lowercased()] else { return }
        do { try await handler(ctx) } catch { if let onError { onError(error, ctx) } }
    }

    // MARK: - Path and options resolution
    static func computePathAndOptions(from interaction: Interaction) -> (String, [String: String]) {
        guard let data = interaction.data else { return ("", [:]) }
        var components: [String] = [data.name]
        var cursorOptions = data.options ?? []
        var leafOptions: [Interaction.ApplicationCommandData.Option] = []
        // Drill into subcommand/subcommand group options if present
        while let first = cursorOptions.first, let type = first.type, (type == 1 || type == 2) { // 1=subcommand, 2=subcommand group
            components.append(first.name)
            cursorOptions = first.options ?? []
        }
        // remaining are leaf options
        leafOptions = cursorOptions
        var map: [String: String] = [:]
        for opt in leafOptions {
            if let v = opt.value { map[opt.name] = v }
        }
        return (components.joined(separator: " "), map)
    }
}
