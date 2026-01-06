//
//  Poll.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Represents a Discord poll
public struct Poll: Codable, Sendable {
    /// The question of the poll. Only `text` is supported.
    public let question: PollMedia
    /// Each of the answers available in the poll.
    public let answers: [PollAnswer]
    /// The time when the poll expires.
    public let expiry: Date?
    /// Whether a user can select multiple answers
    public let allow_multiselect: Bool
    /// The layout type of the poll
    public let layout_type: PollLayoutType
    /// The results of the poll
    public let results: PollResults?

    public enum PollLayoutType: Int, Codable, Sendable {
        case default = 1
    }
}

/// Represents a poll answer
public struct PollAnswer: Codable, Sendable {
    /// The ID of the answer
    public let answer_id: Int
    /// The data of the answer
    public let poll_media: PollMedia
}

/// Represents poll media (text or emoji)
public struct PollMedia: Codable, Sendable {
    /// The text of the field
    public let text: String?
    /// The emoji of the field
    public let emoji: PartialEmoji?
}

/// Represents a partial emoji
public struct PartialEmoji: Codable, Sendable {
    /// Emoji id
    public let id: Snowflake?
    /// Emoji name
    public let name: String?
    /// Whether this emoji is animated
    public let animated: Bool?
}

/// Represents poll results
public struct PollResults: Codable, Sendable {
    /// Whether the votes have been precisely counted
    public let is_finalized: Bool
    /// The counts for each answer
    public let answer_counts: [PollAnswerCount]
}

/// Represents the count for a poll answer
public struct PollAnswerCount: Codable, Sendable {
    /// The answer_id
    public let id: Int
    /// The number of votes for this answer
    public let count: Int
    /// Whether the current user voted for this answer
    public let me_voted: Bool
}

/// Parameters for creating a message poll
public struct CreateMessagePoll: Codable, Sendable {
    /// The question of the poll. Only text is supported.
    public let question: PollMedia
    /// Each of the answers available in the poll. A maximum of 10 answers can be set. Only text is supported.
    public let answers: [PollAnswer]
    /// Number of hours the poll should be open for, up to 32 days (default 24)
    public let duration: Int?
    /// Whether a user can select multiple answers (default false)
    public let allow_multiselect: Bool?
    /// The layout type of the poll (default 1)
    public let layout_type: PollLayoutType?

    public init(
        question: PollMedia,
        answers: [PollAnswer],
        duration: Int? = nil,
        allowMultiselect: Bool? = nil,
        layoutType: PollLayoutType? = nil
    ) {
        self.question = question
        self.answers = answers
        self.duration = duration
        self.allow_multiselect = allowMultiselect
        self.layout_type = layoutType
    }
}

/// Represents a poll voter
public struct PollVoter: Codable, Sendable {
    /// The user who voted
    public let user: User
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/Models/Poll.swift