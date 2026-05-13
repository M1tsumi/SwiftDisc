import Foundation

/// Represents a Discord embed.
///
/// Embeds are rich content objects that can be attached to messages.
/// They support titles, descriptions, fields, images, videos, and more.
///
/// ## Example
///
/// ```swift
/// let embed = Embed(
///     title: "Server Status",
///     description: "All systems operational",
///     color: 0x00ff00,  // Green
///     fields: [
///         Embed.Field(name: "Users", value: "1,234", inline: true),
///         Embed.Field(name: "Channels", value: "56", inline: true)
///     ]
/// )
/// try await client.sendMessage(channelId: channelId, embeds: [embed])
/// ```
///
/// ## Limits
/// - Title: 256 characters
/// - Description: 4096 characters
/// - Fields: Up to 25 fields
/// - Field name: 256 characters
/// - Field value: 1024 characters
/// - Footer text: 2048 characters
/// - Author name: 256 characters
///
/// ## Related Topics
/// - ``EmbedBuilder``
/// - ``DiscordClient/sendMessage(channelId:content:embeds:)``
public struct Embed: Codable, Hashable, Sendable {
    /// Represents a footer for an embed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let footer = Embed.Footer(
    ///     text: "Powered by SwiftDisc",
    ///     icon_url: "https://example.com/icon.png"
    /// )
    /// ```
    public struct Footer: Codable, Hashable, Sendable {
        /// The footer text (up to 2048 characters).
        public let text: String
        
        /// The URL of the footer icon.
        public let icon_url: String?
        
        /// A proxied URL of the footer icon.
        public let proxy_icon_url: String?
        
        public init(text: String, icon_url: String? = nil, proxy_icon_url: String? = nil) {
            self.text = text
            self.icon_url = icon_url
            self.proxy_icon_url = proxy_icon_url
        }
    }
    /// Represents an author for an embed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let author = Embed.Author(
    ///     name: "Server Admin",
    ///     url: "https://example.com",
    ///     icon_url: "https://example.com/avatar.png"
    /// )
    /// ```
    public struct Author: Codable, Hashable, Sendable {
        /// The author name (up to 256 characters).
        public let name: String
        
        /// The URL to open when clicking the author name.
        public let url: String?
        
        /// The URL of the author icon.
        public let icon_url: String?
        
        public init(name: String, url: String? = nil, icon_url: String? = nil) {
            self.name = name
            self.url = url
            self.icon_url = icon_url
        }
    }
    /// Represents a field in an embed.
    ///
    /// Fields are key-value pairs that can be displayed inline or as a list.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let field1 = Embed.Field(name: "Users", value: "1,234", inline: true)
    /// let field2 = Embed.Field(name: "Channels", value: "56", inline: true)
    /// let field3 = Embed.Field(name: "Created", value: "2024-01-01", inline: false)
    /// ```
    public struct Field: Codable, Hashable, Sendable {
        /// The field name (up to 256 characters).
        public let name: String
        
        /// The field value (up to 1024 characters).
        public let value: String
        
        /// Whether the field should be displayed inline.
        ///
        /// Inline fields are displayed in a row (up to 3 per row).
        public let inline: Bool?
        
        public init(name: String, value: String, inline: Bool? = nil) {
            self.name = name
            self.value = value
            self.inline = inline
        }
    }
    /// Represents a video in an embed.
    ///
    /// Videos are typically auto-generated from URLs in the embed content.
    public struct Video: Codable, Hashable, Sendable {
        /// The URL of the video.
        public let url: String?
        
        /// A proxied URL of the video.
        public let proxy_url: String?
        
        /// The height of the video.
        public let height: Int?
        
        /// The width of the video.
        public let width: Int?
        
        public init(url: String? = nil, proxy_url: String? = nil, height: Int? = nil, width: Int? = nil) {
            self.url = url
            self.proxy_url = proxy_url
            self.height = height
            self.width = width
        }
    }
    /// The title of the embed (up to 256 characters).
    public let title: String?
    
    /// The description of the embed (up to 4096 characters).
    public let description: String?
    
    /// The URL of the embed (opens when clicking the title).
    public let url: String?
    
    /// The color of the embed sidebar (as an integer, e.g., 0x00ff00 for green).
    public let color: Int?
    
    /// The footer information.
    public let footer: Footer?
    
    /// The author information.
    public let author: Author?
    
    /// An array of fields (up to 25 fields).
    public let fields: [Field]?
    
    /// The thumbnail image.
    public let thumbnail: Image?
    
    /// The main image.
    public let image: Image?
    
    /// The video information.
    public let video: Video?
    
    /// The provider information (for link embeds).
    public let provider: Provider?
    
    /// The timestamp of the embed (ISO8601 timestamp).
    public let timestamp: String?

    /// Represents an image in an embed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let image = Embed.Image(url: "https://example.com/image.png")
    /// ```
    public struct Image: Codable, Hashable, Sendable {
        /// The URL of the image.
        public let url: String?
        
        /// A proxied URL of the image.
        public let proxy_url: String?
        
        /// The height of the image.
        public let height: Int?
        
        /// The width of the image.
        public let width: Int?
        
        public init(url: String? = nil, proxy_url: String? = nil, height: Int? = nil, width: Int? = nil) {
            self.url = url
            self.proxy_url = proxy_url
            self.height = height
            self.width = width
        }
    }
    /// Represents a provider for link embeds.
    ///
    /// Provider information is auto-generated for link embeds.
    public struct Provider: Codable, Hashable, Sendable {
        /// The name of the provider.
        public let name: String?
        
        /// The URL of the provider.
        public let url: String?
        
        public init(name: String? = nil, url: String? = nil) {
            self.name = name
            self.url = url
        }
    }

    /// Creates a new embed.
    ///
    /// - Parameters:
    ///   - title: The title of the embed (up to 256 characters).
    ///   - description: The description of the embed (up to 4096 characters).
    ///   - url: The URL of the embed.
    ///   - color: The color of the embed sidebar (as an integer).
    ///   - footer: The footer information.
    ///   - author: The author information.
    ///   - fields: An array of fields (up to 25 fields).
    ///   - thumbnail: The thumbnail image.
    ///   - image: The main image.
    ///   - video: The video information.
    ///   - provider: The provider information.
    ///   - timestamp: The timestamp of the embed (ISO8601 timestamp).
    public init(title: String? = nil, description: String? = nil, url: String? = nil, color: Int? = nil, footer: Footer? = nil, author: Author? = nil, fields: [Field]? = nil, thumbnail: Image? = nil, image: Image? = nil, video: Video? = nil, provider: Provider? = nil, timestamp: String? = nil) {
        self.title = title
        self.description = description
        self.url = url
        self.color = color
        self.footer = footer
        self.author = author
        self.fields = fields
        self.thumbnail = thumbnail
        self.image = image
        self.video = video
        self.provider = provider
        self.timestamp = timestamp
    }
}
