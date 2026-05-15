import Foundation

/// Represents a Discord interaction.
///
/// Interactions are the primary way users interact with bots through slash commands,
/// buttons, select menus, modals, and context menus.
///
/// ## Interaction Types
/// - `1`: PING
/// - `2`: APPLICATION_COMMAND (slash command)
/// - `3`: MESSAGE_COMPONENT (button/select menu)
/// - `4`: AUTOCOMPLETE
/// - `5`: MODAL_SUBMIT
///
/// ## Example
///
/// ```swift
/// await client.setOnInteraction { interaction in
///     guard interaction.type == 2 else { return }
///     guard let data = interaction.data else { return }
///     print("Command: \(data.name ?? "unknown")")
/// }
/// ```
///
/// ## Related Topics
/// - ``DiscordClient/slashCommands``
/// - ``CommandRouter``
/// - ``AutocompleteRouter``
public struct Interaction: Codable, Hashable, Sendable {
    /// The ID of the interaction.
    public let id: InteractionID
    
    /// The ID of the application the interaction is for.
    public let application_id: ApplicationID
    
    /// The type of interaction (1-5, see Interaction Types in struct documentation).
    public let type: Int
    
    /// The command data for the interaction.
    public let data: ApplicationCommandData?
    
    /// The guild ID the interaction was sent in (null for DMs).
    public let guild_id: GuildID?
    
    /// The channel the interaction was sent in (partial channel object).
    public let channel: ResolvedChannel?
    
    /// The channel ID the interaction was sent in.
    public let channel_id: ChannelID?
    
    /// The member who invoked the interaction (guild interactions only).
    public let member: GuildMember?
    
    /// The user who invoked the interaction (DM interactions only).
    public let user: User?
    
    /// The interaction token used for follow-up responses.
    public let token: String
    
    /// The version of the interaction.
    public let version: Int?
    
    /// The message the interaction was sent for (component interactions only).
    public let message: Box<Message>?
    
    /// The permissions the bot has in the channel.
    public let app_permissions: String?
    
    /// The locale of the user who invoked the interaction.
    public let locale: String?
    
    /// The locale of the guild the interaction was sent in.
    public let guild_locale: String?
    
    /// The authorizing integration owners.
    public let authorizing_integration_owners: [String: String]?
    
    /// The context of the interaction (0-2).

    public let context: Int?

    // MARK: - Nested Types

    /// Represents a resolved channel in an interaction.
    public struct ResolvedChannel: Codable, Hashable, Sendable {
        /// The ID of the channel.
        public let id: ChannelID
        
        /// The type of channel.
        public let type: Int
        
        /// The name of the channel.
        public let name: String?
        
        /// The permissions of the channel.
        public let permissions: String?
        
        /// The parent ID of the channel.
        public let parent_id: ChannelID?
        
        /// The flags of the channel.
        public let flags: Int?
    }

    /// Represents a resolved role in an interaction.
    public struct ResolvedRole: Codable, Hashable, Sendable {
        /// The ID of the role.
        public let id: RoleID
        
        /// The name of the role.
        public let name: String?
        
        /// The color of the role.
        public let color: Int?
        
        /// Whether the role is hoisted (displayed separately in member list).
        public let hoist: Bool?
        
        /// The icon hash of the role.
        public let icon: String?
        
        /// The unicode emoji for the role.
        public let unicode_emoji: String?
        
        /// The position of the role.
        public let position: Int?
        
        /// The permissions of the role.
        public let permissions: String?
        
        /// Whether the role is managed by an integration.
        public let managed: Bool?
        
        /// Whether the role is mentionable.
        public let mentionable: Bool?
        
        /// The flags of the role.
        public let flags: Int?
    }

    /// Represents a resolved member in an interaction.
    public struct ResolvedMember: Codable, Hashable, Sendable {
        /// The roles of the member.
        public let roles: [RoleID]
        
        /// When the user started boosting the guild.
        public let premium_since: String?
        
        /// Whether the member is pending membership screening.
        public let pending: Bool?
        
        /// The nickname of the member.
        public let nick: String?
        
        /// The avatar hash of the member.
        public let avatar: String?
        
        /// When the user's timeout will expire.
        public let communication_disabled_until: String?
        
        /// The flags of the member.
        public let flags: Int?
        
        /// When the member joined the guild.
        public let joined_at: String?
    }

    /// Represents a resolved attachment in an interaction.
    public struct ResolvedAttachment: Codable, Hashable, Sendable {
        /// The ID of the attachment.
        public let id: AttachmentID
        
        /// The filename of the attachment.
        public let filename: String
        
        /// The size of the attachment in bytes.
        public let size: Int?
        
        /// The URL of the attachment.
        public let url: String
        
        /// The proxied URL of the attachment.
        public let proxy_url: String?
        
        /// The content type of the attachment.
        public let content_type: String?
        
        /// The description of the attachment (alt text).
        public let description: String?
        
        /// The duration of the attachment in seconds (for audio/video).
        public let duration_secs: Double?
        
        /// The waveform of the attachment (for audio).
        public let waveform: String?
        
        /// The height of the attachment (for images/video).
        public let height: Int?
        
        /// The width of the attachment (for images/video).
        public let width: Int?
        
        /// Whether the attachment is ephemeral.
        public let ephemeral: Bool?
        
        /// The flags of the attachment.
        public let flags: Int?
    }

    /// Represents resolved data in an interaction.
    ///
/// Contains resolved entities from command options (users, members, roles, channels, messages, attachments).
    public struct ResolvedData: Codable, Hashable, Sendable {
        /// Resolved users.
        public let users: [UserID: User]?
        
        /// Resolved members.
        public let members: [UserID: ResolvedMember]?
        
        /// Resolved roles.
        public let roles: [RoleID: ResolvedRole]?
        
        /// Resolved channels.
        public let channels: [ChannelID: ResolvedChannel]?
        
        /// Resolved messages.
        public let messages: [MessageID: Box<Message>]?
        
        /// Resolved attachments.
        public let attachments: [AttachmentID: ResolvedAttachment]?
    }

    /// Represents application command data in an interaction.
    public struct ApplicationCommandData: Codable, Hashable, Sendable {
        /// The ID of the command.
        public let id: InteractionID?
        
        /// The name of the command (absent for component/modal interactions).
        public let name: String?
        
        /// The type of the command.
        public let type: Int?
        
        /// Resolved data from command options.
        public let resolved: ResolvedData?
        
        /// The options for the command.
        public let options: [Option]?
        
        /// The custom ID of the component (component interactions).
        public let custom_id: String?
        
        /// The type of the component (component interactions).
        public let component_type: Int?
        
        /// The values selected (select menu interactions).
        public let values: [String]?
        
        /// The target ID (context menu interactions).
        public let target_id: String?
        
        /// The components submitted (modal submit interactions).
        public let components: [MessageComponent]?
        
        /// The attachments submitted (attachment command input).
        public let attachments: [ResolvedAttachment]?

        /// Represents a command option.
        public struct Option: Codable, Hashable, Sendable {
            /// The name of the option.
            public let name: String
            
            /// The type of the option.
            public let type: Int?
            
            /// The value of the option.
            public let value: JSONValue?
            
            /// Sub-options (for group/subcommand options).
            public let options: [Option]?
            
            /// Whether this option is currently focused (autocomplete).
            public let focused: Bool?
        }
    }
}
