import Foundation

/// Routes autocomplete interactions to per-option providers.
/// Declared as an `actor` so provider registration and dispatch are
/// data-race free across concurrent tasks.
public actor AutocompleteRouter {
    /// Per-invocation context provided to every autocomplete provider.
    public struct Context: Sendable {
        public let client: DiscordClient
        public let interaction: Interaction
        /// The resolved command path (shares logic with `SlashCommandRouter`).
        public let path: String
        /// The name of the currently-focused option, if any.
        public let focusedOption: String?
        /// The current partial value typed by the user, if any.
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
                        if let t = o.type, t == 1 || t == 2 {
                            walk(o.options ?? [])
                        } else if o.focused == true {
                            fName = o.name
                            fValue = o.value?.stringValue
                        }
                    }
                }
                walk(opts)
            }
            self.focusedOption = fName
            self.focusedValue = fValue
        }
    }

    /// The async, Sendable provider type that returns autocomplete choices.
    public typealias Provider = @Sendable (Context) async throws -> [DiscordClient.AutocompleteChoice]

    /// key: "path|option"
    private var providers: [String: Provider] = [:]

    public init() {}

    /// Register an autocomplete provider for a specific command path + option name.
    public func register(path: String, option: String, provider: @escaping Provider) {
        providers[AutocompleteRouter.key(path: path, option: option)] = provider
    }

    /// Dispatch an autocomplete interaction to the matching provider.
    public func handle(interaction: Interaction, client: DiscordClient) async {
        let ctx = Context(client: client, interaction: interaction)
        guard let opt = ctx.focusedOption else { return }
        let k = AutocompleteRouter.key(path: ctx.path, option: opt)
        guard let provider = providers[k] else { return }
        do {
            let choices = try await provider(ctx)
            try await client.createAutocompleteResponse(
                interactionId: interaction.id,
                token: interaction.token,
                choices: choices
            )
        } catch {
            // Only log non-cancelled errors to avoid noise during typing
            if case DiscordError.cancelled = error { return }
            print("[AutocompleteRouter] Failed for '\(ctx.path)' | '\(opt)': \(error)")
        }
    }

    nonisolated private static func key(path: String, option: String) -> String {
        path.lowercased() + "|" + option.lowercased()
    }
}
