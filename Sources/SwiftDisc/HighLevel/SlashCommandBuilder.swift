//
//  SlashCommandBuilder.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public final class SlashCommandBuilder {
    public final class OptionBuilder {
        private var option: DiscordClient.ApplicationCommandOption
        private var choices: [DiscordClient.ApplicationCommandOption.Choice] = []
        public init(type: DiscordClient.ApplicationCommandOption.ApplicationCommandOptionType, name: String, description: String, required: Bool? = nil) {
            self.option = .init(type: type, name: name, description: description, required: required, choices: nil)
        }
        @discardableResult
        public func required(_ req: Bool = true) -> OptionBuilder { option = .init(type: option.type, name: option.name, description: option.description, required: req, choices: option.choices); return self }
        @discardableResult
        public func choice(_ name: String, _ value: String) -> OptionBuilder {
            choices.append(.init(name: name, value: value));
            option = .init(type: option.type, name: option.name, description: option.description, required: option.required, choices: choices)
            return self
        }
        public func build() -> DiscordClient.ApplicationCommandOption { option }
    }

    public let name: String
    public let description: String
    private var options: [DiscordClient.ApplicationCommandOption] = []
    private var dmPermission: Bool?
    private var defaultMemberPermissions: String?

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }

    @discardableResult
    public func string(_ name: String, _ description: String, required: Bool? = nil, configure: ((OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        let b = OptionBuilder(type: .string, name: name, description: description, required: required)
        configure?(b)
        options.append(b.build())
        return self
    }

    @discardableResult
    public func integer(_ name: String, _ description: String, required: Bool? = nil, configure: ((OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        let b = OptionBuilder(type: .integer, name: name, description: description, required: required)
        configure?(b)
        options.append(b.build())
        return self
    }

    @discardableResult
    public func number(_ name: String, _ description: String, required: Bool? = nil, configure: ((OptionBuilder) -> Void)? = nil) -> SlashCommandBuilder {
        let b = OptionBuilder(type: .number, name: name, description: description, required: required)
        configure?(b)
        options.append(b.build())
        return self
    }

    @discardableResult
    public func boolean(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .boolean, name: name, description: description, required: required, choices: nil))
        return self
    }

    @discardableResult
    public func user(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .user, name: name, description: description, required: required, choices: nil))
        return self
    }

    @discardableResult
    public func channel(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .channel, name: name, description: description, required: required, choices: nil))
        return self
    }

    @discardableResult
    public func role(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .role, name: name, description: description, required: required, choices: nil))
        return self
    }

    @discardableResult
    public func mentionable(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .mentionable, name: name, description: description, required: required, choices: nil))
        return self
    }

    @discardableResult
    public func attachment(_ name: String, _ description: String, required: Bool? = nil) -> SlashCommandBuilder {
        options.append(.init(type: .attachment, name: name, description: description, required: required, choices: nil))
        return self
    }

    @discardableResult
    public func dmPermission(_ allow: Bool) -> SlashCommandBuilder { self.dmPermission = allow; return self }

    @discardableResult
    public func defaultMemberPermissions(_ perms: String) -> SlashCommandBuilder { self.defaultMemberPermissions = perms; return self }

    public func build() -> DiscordClient.ApplicationCommandCreate {
        .init(name: name, description: description, options: options, default_member_permissions: defaultMemberPermissions, dm_permission: dmPermission)
    }
}
