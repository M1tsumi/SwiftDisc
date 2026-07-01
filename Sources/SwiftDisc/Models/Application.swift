import Foundation

/// Represents a Discord application (bot).
public struct Application: Codable, Hashable, Sendable {
    public let id: ApplicationID
    public let name: String
    public let icon: String?
    public let description: String
    public let rpc_origins: [String]?
    public let bot_public: Bool
    public let bot_require_code_grant: Bool
    public let terms_of_service_url: String?
    public let privacy_policy_url: String?
    public let owner: PartialGuild?
    public let verify_key: String
    public let team: Team?
    public let guild_id: GuildID?
    public let primary_sku_id: SKUID?
    public let slug: String?
    public let cover_image: String?
    public let flags: Int?
    public let tags: [String]?
    public let install_params: InstallParams?
    public let custom_install_url: String?
    public let role_connections_verification_url: String?
    public let integration_types_config: [Int: IntegrationTypeConfig]?
    public let flags_new: String?

    public struct Team: Codable, Hashable, Sendable {
        public let id: TeamID
        public let icon: String?
        public let members: [TeamMember]
        public let name: String
        public let owner_user_id: UserID
    }

    public struct TeamMember: Codable, Hashable, Sendable {
        public let membership_state: Int
        public let team_id: TeamID
        public let user: User
        public let role: String
    }

    public struct InstallParams: Codable, Hashable, Sendable {
        public let scopes: [String]
        public let permissions: String
    }

    public struct IntegrationTypeConfig: Codable, Hashable, Sendable {
        public let oauth2_install_params: InstallParams?
    }
}
