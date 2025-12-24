import Foundation

// MARK: - Guild Onboarding
public struct GuildOnboarding: Codable, Hashable {
    public let guild_id: GuildID
    public let prompts: [OnboardingPrompt]
    public let default_channel_ids: [ChannelID]
    public let enabled: Bool
    public let mode: OnboardingMode
}

public struct OnboardingPrompt: Codable, Hashable {
    public let id: String
    public let type: OnboardingPromptType
    public let options: [OnboardingPromptOption]
    public let title: String
    public let single_select: Bool
    public let required: Bool
    public let in_onboarding: Bool
}

public struct OnboardingPromptOption: Codable, Hashable {
    public let id: String
    public let channel_ids: [ChannelID]
    public let role_ids: [RoleID]
    public let emoji: PartialEmoji?
    public let title: String
    public let description: String?
}

public enum OnboardingMode: Int, Codable, Hashable {
    case onboardingDefault = 0
    case onboardingAdvanced = 1
}

public enum OnboardingPromptType: Int, Codable, Hashable {
    case multipleChoice = 0
    case dropdown = 1
}

// MARK: - Onboarding Update
public struct GuildOnboardingUpdate: Codable, Hashable {
    public let prompts: [OnboardingPrompt]?
    public let default_channel_ids: [ChannelID]?
    public let enabled: Bool?
    public let mode: OnboardingMode?
    
    public init(
        prompts: [OnboardingPrompt]? = nil,
        default_channel_ids: [ChannelID]? = nil,
        enabled: Bool? = nil,
        mode: OnboardingMode? = nil
    ) {
        self.prompts = prompts
        self.default_channel_ids = default_channel_ids
        self.enabled = enabled
        self.mode = mode
    }
}

// MARK: - Welcome Screen
public struct WelcomeScreen: Codable, Hashable {
    public let description: String?
    public let welcome_channels: [WelcomeChannel]
}

public struct WelcomeChannel: Codable, Hashable {
    public let channel_id: ChannelID
    public let description: String
    public let emoji_id: EmojiID?
    public let emoji_name: String?
}

// MARK: - Welcome Screen Update
public struct WelcomeScreenUpdate: Codable, Hashable {
    public let description: String?
    public let welcome_channels: [WelcomeChannel]?
    
    public init(description: String? = nil, welcome_channels: [WelcomeChannel]? = nil) {
        self.description = description
        self.welcome_channels = welcome_channels
    }
}
