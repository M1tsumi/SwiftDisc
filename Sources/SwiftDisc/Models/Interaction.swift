import Foundation

/// Discord interaction payload (slash command, component, modal submit, autocomplete, ping).
/// This mirrors the Discord HTTP and gateway shape closely so all option/value types decode correctly,
/// including attachment command options and resolved maps.
public struct Interaction: Codable, Hashable {
    public let id: InteractionID
    public let application_id: ApplicationID
    public let type: Int
    public let data: ApplicationCommandData?
    public let guild_id: GuildID?
    public let channel: ResolvedChannel?
    public let channel_id: ChannelID?
    public let member: GuildMember?
    public let user: User?
    public let token: String
    public let version: Int?
    public let message: Message?
    public let app_permissions: String?
    public let locale: String?
    public let guild_locale: String?
    public let authorizing_integration_owners: [String: String]?
    public let context: Int?

    // MARK: - Nested Types

    public struct ResolvedChannel: Codable, Hashable {
        public let id: ChannelID
        public let type: Int
        public let name: String?
        public let permissions: String?
        public let parent_id: ChannelID?
        public let flags: Int?
    }

    public struct ResolvedRole: Codable, Hashable {
        public let id: RoleID
        public let name: String?
        public let color: Int?
        public let hoist: Bool?
        public let icon: String?
        public let unicode_emoji: String?
        public let position: Int?
        public let permissions: String?
        public let managed: Bool?
        public let mentionable: Bool?
        public let flags: Int?
    }

    public struct ResolvedMember: Codable, Hashable {
        public let roles: [RoleID]
        public let premium_since: String?
        public let pending: Bool?
        public let nick: String?
        public let avatar: String?
        public let communication_disabled_until: String?
        public let flags: Int?
        public let joined_at: String?
    }

    public struct ResolvedAttachment: Codable, Hashable {
        public let id: AttachmentID
        public let filename: String
        public let size: Int?
        public let url: String
        public let proxy_url: String?
        public let content_type: String?
        public let description: String?
        public let duration_secs: Double?
        public let waveform: String?
        public let height: Int?
        public let width: Int?
        public let ephemeral: Bool?
    }

    public struct ResolvedData: Codable, Hashable {
        public let users: [UserID: User]?
        public let members: [UserID: ResolvedMember]?
        public let roles: [RoleID: ResolvedRole]?
        public let channels: [ChannelID: ResolvedChannel]?
        public let messages: [MessageID: Message]?
        public let attachments: [AttachmentID: ResolvedAttachment]?
    }

    public struct ApplicationCommandData: Codable, Hashable {
        public let id: InteractionID?
        public let name: String
        public let type: Int?
        public let resolved: ResolvedData?
        public let options: [Option]?
        // Component interaction fields
        public let custom_id: String?
        public let component_type: Int?
        public let values: [String]?
        // Command + context menu targeting
        public let target_id: String?
        // Modal submit specific
        public let components: [MessageComponent]?
        // Attachment command input
        public let attachments: [ResolvedAttachment]?

        public struct Option: Codable, Hashable {
            public let name: String
            public let type: Int?
            public let value: JSONValue?
            public let options: [Option]?
            public let focused: Bool?
        }
    }
}
