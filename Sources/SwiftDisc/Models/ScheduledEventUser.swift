//
//  ScheduledEventUser.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct GuildScheduledEventUser: Codable, Hashable {
    public let guild_scheduled_event_id: GuildScheduledEventID
    public let user: User
    public let member: GuildMember?
}
