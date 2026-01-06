//
//  GuildMember.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct GuildMember: Codable, Hashable {
    public let user: User?
    public let nick: String?
    public let avatar: String?
    public let roles: [RoleID]
    public let joined_at: String?
    public let deaf: Bool?
    public let mute: Bool?
}
