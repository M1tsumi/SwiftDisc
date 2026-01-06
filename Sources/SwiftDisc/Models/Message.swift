//
//  Message.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Message: Codable, Hashable {
    public let id: MessageID
    public let channel_id: ChannelID
    public let author: User
    public let content: String
    public let embeds: [Embed]?
    public let attachments: [Attachment]?
    public let mentions: [User]?
    public let components: [MessageComponent]?
    public let reactions: [Reaction]?
}

public struct Reaction: Codable, Hashable {
    public let count: Int
    public let me: Bool
    public let emoji: PartialEmoji
}

public struct PartialEmoji: Codable, Hashable {
    public let id: EmojiID?
    public let name: String?
    public let animated: Bool?
}
