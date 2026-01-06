//
//  Guild.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Guild: Codable, Hashable {
    public let id: GuildID
    public let name: String
    public let owner_id: UserID?
    public let member_count: Int?
}
