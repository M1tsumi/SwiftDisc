//
//  Invite.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Invite: Codable, Hashable {
    public struct InviteGuild: Codable, Hashable { public let id: GuildID; public let name: String? }
    public struct InviteChannel: Codable, Hashable { public let id: ChannelID; public let name: String?; public let type: Int? }

    public let code: String
    public let guild: InviteGuild?
    public let channel: InviteChannel?
    public let inviter: User?
    public let uses: Int?
    public let max_uses: Int?
    public let max_age: Int?
    public let temporary: Bool?
    public let created_at: String?
    public let expires_at: String?
}
