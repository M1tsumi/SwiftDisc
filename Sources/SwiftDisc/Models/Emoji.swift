//
//  Emoji.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Emoji: Codable, Hashable {
    public let id: EmojiID?
    public let name: String?
    public let roles: [RoleID]?
    public let user: User?
    public let require_colons: Bool?
    public let managed: Bool?
    public let animated: Bool?
    public let available: Bool?
}
