import Foundation

/// Represents a guild's onboarding flow for new members.
public struct Onboarding: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let prompts: [OnboardingPrompt]
    public let default_channel_ids: [ChannelID]
    public let enabled: Bool
    public let mode: Int
    public let default_recommendation_channel_ids: [ChannelID]?
}

/// A single prompt within a guild onboarding flow.
public struct OnboardingPrompt: Codable, Hashable, Sendable {
    public let id: Snowflake<OnboardingPrompt>
    public let type: Int
    public let options: [OnboardingPromptOption]
    public let title: String
    public let single_select: Bool
    public let required: Bool
    public let in_onboarding: Bool
}

/// An option within an onboarding prompt.
public struct OnboardingPromptOption: Codable, Hashable, Sendable {
    public let id: Snowflake<OnboardingPromptOption>
    public let channel_ids: [ChannelID]?
    public let role_ids: [RoleID]?
    public let emoji: PartialEmoji?
    public let title: String
    public let description: String?
}
