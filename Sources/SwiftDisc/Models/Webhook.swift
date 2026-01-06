//
//  Webhook.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Webhook: Codable, Hashable {
    public let id: WebhookID
    public let type: Int
    public let channel_id: ChannelID?
    public let guild_id: GuildID?
    public let name: String?
    public let token: String?
}
