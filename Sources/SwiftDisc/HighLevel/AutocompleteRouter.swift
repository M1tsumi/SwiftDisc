//
//  AutocompleteRouter.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public final class AutocompleteRouter {
    public struct Context {
        public let client: DiscordClient
        public let interaction: Interaction
        public let path: String
        public let focusedOption: String?
        public let focusedValue: String?
        public init(client: DiscordClient, interaction: Interaction) {
            self.client = client
            self.interaction = interaction
            let (p, _) = SlashCommandRouter.computePathAndOptions(from: interaction)
            self.path = p
            var fName: String? = nil
            var fValue: String? = nil
            if let opts = interaction.data?.options {
                func walk(_ options: [Interaction.ApplicationCommandData.Option]) {
                    for o in options {
                        if let t = o.type, t == 1 || t == 2 { // subcommand/group
                            walk(o.options ?? [])
                        } else if o.focused == true {
                            fName = o.name
                            fValue = o.value
                        }
                    }
                }
                walk(opts)
            }
            self.focusedOption = fName
            self.focusedValue = fValue
        }
    }

    public typealias Provider = (Context) async throws -> [DiscordClient.AutocompleteChoice]

    private var providers: [String: Provider] = [:] // key: "path|option"

    public init() {}

    public func register(path: String, option: String, provider: @escaping Provider) {
        providers[AutocompleteRouter.key(path: path, option: option)] = provider
    }

    public func handle(interaction: Interaction, client: DiscordClient) async {
        let ctx = Context(client: client, interaction: interaction)
        guard let opt = ctx.focusedOption else { return }
        let key = AutocompleteRouter.key(path: ctx.path, option: opt)
        guard let provider = providers[key] else { return }
        do {
            let choices = try await provider(ctx)
            try await client.createAutocompleteResponse(interactionId: interaction.id, token: interaction.token, choices: choices)
        } catch {
            // swallow autocomplete errors to avoid noisy logs for users
        }
    }

    private static func key(path: String, option: String) -> String { path.lowercased() + "|" + option.lowercased() }
}
