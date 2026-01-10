//
//  GuildPreview.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct GuildPreview: Codable, Hashable {
    public let id: GuildID
    public let name: String
    public let icon: String?
    public let splash: String?
    public let discovery_splash: String?
    public let emojis: [Emoji]
    public let features: [String]
    public let approximate_member_count: Int
    public let approximate_presence_count: Int
    public let description: String?
}
