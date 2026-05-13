import Foundation

/// A builder for creating Discord slash commands.
///
/// Use this builder to construct slash commands with options, permissions, and other settings.
/// The builder provides a fluent API for adding command options.
///
/// ## Example
///
/// ```swift
/// let command = SlashCommandBuilder(name: "ban", description: "Ban a user")
///     .string("reason", "The reason for the ban", required: false)
///     .user("target", "The user to ban", required: true)
///     .defaultMemberPermissions("0x0000000000000008") // Ban permission
///     .build()
/// ```
///
/// ## Related Topics
/// - ``DiscordClient/createGlobalApplicationCommand(_:)``
/// - ``SlashCommandRouter``
public final class SlashCommandBuilder: @unchecked Sendable {
    /// A builder for command options.
    public final class OptionBuilder: @unchecked Sendable {
        private var option: DiscordClient.ApplicationCommandOption
        private var choices: [DiscordClient.ApplicationCommandOption.Choice] = []
        
        /// Creates a new option builder.
        ///
        /// - Parameters:
        ///   - type: The option type.
        ///   - name: The option name.
        ///   - description: The option description.
        ///   - required: Whether the option is required.
        public init(type: DiscordClient.ApplicationCommandOption.ApplicationCommandOptionType, name: String, description: String, required: Bool? = nil) {
            self.option = .init(type: type, name: name, description: description, required: required, choices: nil)
        }
        
        /// Sets whether this option is required.
        @discardableResult
        public func required(_ req: Bool = true) -> OptionBuilder { option = .init(type: option.type, name: option.name, description: option.description, required: req, choices: option.choices); return self }
        
        /// Adds a choice for string/integer/number options.
        @discardableResult
        public func choice(_ name: String, _ value: String) -> OptionBuilder {
            choices.append(.init(name: name, name_localizations: nil, value: .string(value)));
            option = .init(type: option.type, name: option.name, description: option.description, required: option.required, choices: choices)
            return self
        }
        
        /// Builds the option.
        public func build() -> DiscordClient.ApplicationCommandOption { option }
    }

    /// The command name.
    public let name: String
    
    /// The command description.
    public let description: String
    
    private var options: [DiscordClient.ApplicationCommandOption] = []
    private var dmPermission: Bool?
    private var defaultMemberPermissions: String?

    /// Creates a new slash command builder.
    ///
    /// - Parameters:
    ///   - name: The command name (lowercase, 1-32 characters, no spaces).
    ///   - description: The command description (1-100 characters).
    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }

    /// Adds a string option.
    @discardableResult
    public func string(_ name: String, _ description: String, required: Bool? = nil, configure: (@Sendable (inout OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        var b = OptionBuilder(type: .string, name: name, description: description, required: required)
        configure?(&b)
        options.append(b.build())
        return self
    }

    /// Adds an integer option.
    @discardableResult
    public func integer(_ name: String, _ description: String, required: Bool? = nil, configure: (@Sendable (inout OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        var b = OptionBuilder(type: .integer, name: name, description: description, required: required)
        configure?(&b)
        options.append(b.build())
        return self
    }

    /// Adds a number option.
    @discardableResult
    public func number(_ name: String, _ description: String, required: Bool? = nil, configure: (@Sendable (inout OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        var b = OptionBuilder(type: .number, name: name, description: description, required: required)
        configure?(&b)
        options.append(b.build())
        return self
    }

    /// Adds a boolean option.
    @discardableResult
    public func boolean(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .boolean, name: name, description: description, required: required, choices: nil))
        return self
    }

    /// Adds a user option.
    @discardableResult
    public func user(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .user, name: name, description: description, required: required, choices: nil))
        return self
    }

    /// Adds a channel option.
    @discardableResult
    public func channel(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .channel, name: name, description: description, required: required, choices: nil))
        return self
    }

    /// Adds a role option.
    @discardableResult
    public func role(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .role, name: name, description: description, required: required, choices: nil))
        return self
    }

    /// Adds a mentionable option (user or role).
    @discardableResult
    public func mentionable(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .mentionable, name: name, description: description, required: required, choices: nil))
        return self
    }

    /// Adds an attachment option.
    @discardableResult
    public func attachment(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .attachment, name: name, description: description, required: required, choices: nil))
        return self
    }

    /// Sets whether the command can be used in DMs.
    @discardableResult
    public func dmPermission(_ allow: Bool) -> SlashCommandBuilder { self.dmPermission = allow; return self }

    /// Sets the default member permissions for the command.
    @discardableResult
    public func defaultMemberPermissions(_ perms: String) -> SlashCommandBuilder { self.defaultMemberPermissions = perms; return self }

    /// Builds the command.
    public func build() -> DiscordClient.ApplicationCommandCreate {
        .init(name: name, description: description, options: options, default_member_permissions: defaultMemberPermissions, dm_permission: dmPermission)
    }
}
