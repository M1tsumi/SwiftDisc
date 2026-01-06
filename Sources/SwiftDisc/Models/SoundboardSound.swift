//
//  SoundboardSound.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Represents a soundboard sound
public struct SoundboardSound: Codable, Sendable {
    /// The ID of the sound
    public let sound_id: Snowflake
    /// The name of the sound
    public let name: String
    /// The volume of the sound, from 0.0 to 1.0
    public let volume: Double?
    /// The ID of the user who created the sound
    public let user_id: Snowflake
    /// Whether the sound can be used. Defaults to true
    public let available: Bool
    /// ID of the guild the sound is in
    public let guild_id: Snowflake?
    /// The emoji ID of the soundboard sound
    public let emoji_id: Snowflake?
    /// The emoji name of the soundboard sound (for custom emojis)
    public let emoji_name: String?

    /// Create a new soundboard sound for creation requests
    public init(
        name: String,
        volume: Double? = nil,
        emojiId: Snowflake? = nil,
        emojiName: String? = nil
    ) {
        self.sound_id = Snowflake(0) // Will be set by Discord
        self.name = name
        self.volume = volume
        self.user_id = Snowflake(0) // Will be set by Discord
        self.available = true
        self.guild_id = nil
        self.emoji_id = emojiId
        self.emoji_name = emojiName
    }
}

/// Parameters for creating a guild soundboard sound
public struct CreateGuildSoundboardSound: Codable, Sendable {
    /// The name of the sound (1-32 characters)
    public let name: String
    /// The base64 encoded mp3, ogg, or wav sound data (max 512KB)
    public let sound: String
    /// The volume of the sound, from 0.0 to 1.0 (default 1.0)
    public let volume: Double?
    /// The emoji ID to use for the sound
    public let emoji_id: Snowflake?
    /// The emoji name to use for the sound
    public let emoji_name: String?

    public init(
        name: String,
        sound: String,
        volume: Double? = nil,
        emojiId: Snowflake? = nil,
        emojiName: String? = nil
    ) {
        self.name = name
        self.sound = sound
        self.volume = volume
        self.emoji_id = emojiId
        self.emoji_name = emojiName
    }
}

/// Parameters for modifying a guild soundboard sound
public struct ModifyGuildSoundboardSound: Codable, Sendable {
    /// The name of the sound (1-32 characters)
    public let name: String?
    /// The volume of the sound, from 0.0 to 1.0
    public let volume: Double?
    /// The emoji ID to use for the sound
    public let emoji_id: Snowflake?
    /// The emoji name to use for the sound
    public let emoji_name: String?

    public init(
        name: String? = nil,
        volume: Double? = nil,
        emojiId: Snowflake? = nil,
        emojiName: String? = nil
    ) {
        self.name = name
        self.volume = volume
        self.emoji_id = emojiId
        self.emoji_name = emojiName
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/Models/SoundboardSound.swift