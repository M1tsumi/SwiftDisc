//
//  Intents.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct GatewayIntents: OptionSet, Codable, Hashable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    public static let guilds = GatewayIntents(rawValue: 1 << 0)
    public static let guildMembers = GatewayIntents(rawValue: 1 << 1)
    public static let guildModeration = GatewayIntents(rawValue: 1 << 2)
    public static let guildEmojisAndStickers = GatewayIntents(rawValue: 1 << 3)
    public static let guildIntegrations = GatewayIntents(rawValue: 1 << 4)
    public static let guildWebhooks = GatewayIntents(rawValue: 1 << 5)
    public static let guildInvites = GatewayIntents(rawValue: 1 << 6)
    public static let guildVoiceStates = GatewayIntents(rawValue: 1 << 7)
    public static let guildPresences = GatewayIntents(rawValue: 1 << 8)
    public static let guildMessages = GatewayIntents(rawValue: 1 << 9)
    public static let guildMessageReactions = GatewayIntents(rawValue: 1 << 10)
    public static let guildMessageTyping = GatewayIntents(rawValue: 1 << 11)
    public static let directMessages = GatewayIntents(rawValue: 1 << 12)
    public static let directMessageReactions = GatewayIntents(rawValue: 1 << 13)
    public static let directMessageTyping = GatewayIntents(rawValue: 1 << 14)
    public static let messageContent = GatewayIntents(rawValue: 1 << 15)
    public static let guildScheduledEvents = GatewayIntents(rawValue: 1 << 16)
    public static let autoModerationConfiguration = GatewayIntents(rawValue: 1 << 20)
    public static let autoModerationExecution = GatewayIntents(rawValue: 1 << 21)
}
