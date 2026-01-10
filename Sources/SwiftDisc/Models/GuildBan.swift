//
//  GuildBan.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct GuildBan: Codable, Hashable {
    public let reason: String?
    public let user: User
}
