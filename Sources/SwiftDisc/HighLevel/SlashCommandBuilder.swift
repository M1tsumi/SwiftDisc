import Foundation

/// A builder for creating Discord slash commands and context menu commands.
///
/// Use this builder to construct commands with options, permissions, localization, and other settings.
///
/// ## Examples
///
/// ### Slash command with options
///
/// ```swift
/// let command = SlashCommandBuilder(name: "ban", description: "Ban a user")
///     .string("reason", "The reason for the ban", required: false)
///     .user("target", "The user to ban", required: true)
///     .defaultMemberPermissions("8") // Administrator
///     .build()
/// ```
///
/// ### User context menu command
///
/// ```swift
/// let userCmd = SlashCommandBuilder(name: "Avatar", description: "View avatar")
///     .type(.user)
///     .build()
/// ```
///
/// ### Message context menu command
///
/// ```swift
/// let msgCmd = SlashCommandBuilder(name: "Pin", description: "Pin this message")
///     .type(.message)
///     .build()
/// ```
///
/// ### Command with localizations
///
/// ```swift
/// let cmd = SlashCommandBuilder(name: "ping", description: "Check latency")
///     .nameLocalizations(["es": "ping", "fr": "ping"])
///     .descriptionLocalizations(["es": "Revisa la latencia", "fr": "Verifier la latence"])
///     .build()
/// ```
///
/// ### Command with subcommands
///
/// ```swift
/// let cmd = SlashCommandBuilder(name: "settings", description: "Manage settings")
///     .subCommand("notifications", "Notification preferences") { sub in
///         sub.boolean("enabled", "Enable notifications", required: true)
///     }
///     .subCommand("privacy", "Privacy settings") { sub in
///         sub.string("level", "Privacy level")
///     }
///     .build()
/// ```
public struct SlashCommandBuilder: Sendable {
    /// The command type (1 = CHAT_INPUT, 2 = USER, 3 = MESSAGE).
    public enum CommandType: Int, Sendable {
        case chatInput = 1
        case user = 2
        case message = 3
    }

    /// A builder for command options.
    public struct OptionBuilder: Sendable {
        private var option: DiscordClient.ApplicationCommandOption
        private var choices: [DiscordClient.ApplicationCommandOption.Choice] = []

        public init(type: DiscordClient.ApplicationCommandOption.ApplicationCommandOptionType, name: String, description: String, required: Bool? = nil) {
            self.option = .init(type: type, name: name, description: description, required: required, choices: nil)
        }

        @discardableResult
        public mutating func required(_ req: Bool = true) -> OptionBuilder {
            option = .init(type: option.type, name: option.name, description: option.description, required: req, choices: option.choices)
            return self
        }

        @discardableResult
        public mutating func nameLocalizations(_ loc: [String: String]) -> OptionBuilder {
            option = .init(type: option.type, name: option.name, description: option.description, required: option.required, choices: option.choices, nameLocalizations: loc)
            return self
        }

        @discardableResult
        public mutating func descriptionLocalizations(_ loc: [String: String]) -> OptionBuilder {
            option = .init(type: option.type, name: option.name, description: option.description, required: option.required, choices: option.choices, descriptionLocalizations: loc)
            return self
        }

        @discardableResult
        public mutating func choice(_ name: String, _ value: String) -> OptionBuilder {
            choices.append(.init(name: name, name_localizations: nil, value: .string(value)))
            option = .init(type: option.type, name: option.name, description: option.description, required: option.required, choices: choices)
            return self
        }

        @discardableResult
        public mutating func choice(_ name: String, _ value: Int) -> OptionBuilder {
            choices.append(.init(name: name, name_localizations: nil, value: .int(value)))
            option = .init(type: option.type, name: option.name, description: option.description, required: option.required, choices: choices)
            return self
        }

        @discardableResult
        public mutating func choice(_ name: String, _ value: Double) -> OptionBuilder {
            choices.append(.init(name: name, name_localizations: nil, value: .number(value)))
            option = .init(type: option.type, name: option.name, description: option.description, required: option.required, choices: choices)
            return self
        }

        public func build() -> DiscordClient.ApplicationCommandOption { option }
    }

    public let name: String
    public let description: String

    private var type: CommandType = .chatInput
    private var nameLocalizations: [String: String]?
    private var descriptionLocalizations: [String: String]?
    private var options: [DiscordClient.ApplicationCommandOption] = []
    private var dmPermission: Bool?
    private var defaultMemberPermissions: String?
    private var nsfw: Bool?
    private var contexts: [Int]?

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }

    @discardableResult
    public func type(_ t: CommandType) -> SlashCommandBuilder { var c = self; c.type = t; return c }

    @discardableResult
    public func nameLocalizations(_ loc: [String: String]) -> SlashCommandBuilder { var c = self; c.nameLocalizations = loc; return c }

    @discardableResult
    public func descriptionLocalizations(_ loc: [String: String]) -> SlashCommandBuilder { var c = self; c.descriptionLocalizations = loc; return c }

    @discardableResult
    public func dmPermission(_ allow: Bool) -> SlashCommandBuilder { var c = self; c.dmPermission = allow; return c }

    @discardableResult
    public func defaultMemberPermissions(_ perms: String) -> SlashCommandBuilder { var c = self; c.defaultMemberPermissions = perms; return c }

    @discardableResult
    public func nsfw(_ isNsfw: Bool = true) -> SlashCommandBuilder { var c = self; c.nsfw = isNsfw; return c }

    @discardableResult
    public func contexts(_ ctx: [Int]) -> SlashCommandBuilder { var c = self; c.contexts = ctx; return c }

    @discardableResult
    public func addOption(_ option: DiscordClient.ApplicationCommandOption) -> SlashCommandBuilder {
        var c = self; c.options.append(option); return c
    }

    @discardableResult
    public func string(_ name: String, _ description: String, required: Bool? = nil, configure: (@Sendable (inout OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        var b = OptionBuilder(type: .string, name: name, description: description, required: required)
        configure?(&b)
        return addOption(b.build())
    }

    @discardableResult
    public func integer(_ name: String, _ description: String, required: Bool? = nil, configure: (@Sendable (inout OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        var b = OptionBuilder(type: .integer, name: name, description: description, required: required)
        configure?(&b)
        return addOption(b.build())
    }

    @discardableResult
    public func number(_ name: String, _ description: String, required: Bool? = nil, configure: (@Sendable (inout OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        var b = OptionBuilder(type: .number, name: name, description: description, required: required)
        configure?(&b)
        return addOption(b.build())
    }

    @discardableResult
    public func boolean(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        addOption(.init(type: .boolean, name: name, description: description, required: required, choices: nil))
    }

    @discardableResult
    public func user(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        addOption(.init(type: .user, name: name, description: description, required: required, choices: nil))
    }

    @discardableResult
    public func channel(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        addOption(.init(type: .channel, name: name, description: description, required: required, choices: nil))
    }

    @discardableResult
    public func role(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        addOption(.init(type: .role, name: name, description: description, required: required, choices: nil))
    }

    @discardableResult
    public func mentionable(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        addOption(.init(type: .mentionable, name: name, description: description, required: required, choices: nil))
    }

    @discardableResult
    public func attachment(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        addOption(.init(type: .attachment, name: name, description: description, required: required, choices: nil))
    }

    @discardableResult
    public func subCommand(_ name: String, _ description: String, configure: (@Sendable (inout OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        var b = OptionBuilder(type: .subCommand, name: name, description: description)
        configure?(&b)
        return addOption(b.build())
    }

    @discardableResult
    public func subCommandGroup(_ name: String, _ description: String, configure: (@Sendable (inout OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        var b = OptionBuilder(type: .subCommandGroup, name: name, description: description)
        configure?(&b)
        return addOption(b.build())
    }

    public func build() -> DiscordClient.ApplicationCommandCreate {
        .init(
            name: name,
            description: description,
            options: options.isEmpty ? nil : options,
            default_member_permissions: defaultMemberPermissions,
            dm_permission: dmPermission,
            nameLocalizations: nameLocalizations,
            descriptionLocalizations: descriptionLocalizations,
            type: type != .chatInput ? type.rawValue : nil,
            nsfw: nsfw,
            contexts: contexts
        )
    }
}
