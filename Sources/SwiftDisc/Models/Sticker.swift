import Foundation

/// Represents a Discord sticker.
///
/// Stickers are custom images that can be added to messages.
///
/// ## Example
///
/// ```swift
/// if let stickers = message.sticker_items {
///     for sticker in stickers {
///         print("Sticker: \(sticker.name)")
///     }
/// }
/// ```
public struct Sticker: Codable, Hashable, Sendable {
    /// The sticker ID.
    public let id: StickerID
    
    /// The sticker name.
    public let name: String
    
    /// The sticker description.
    public let description: String?
    
    /// The sticker tags.
    public let tags: String?
    
    /// The sticker type.
    public let type: Int?
    
    /// The sticker format type.
    public let format_type: Int?
    
    /// Whether the sticker is available.
    public let available: Bool?
    
    /// The guild ID for guild stickers.
    public let guild_id: GuildID?
}

/// A partial sticker object.
///
/// Used in message contexts where full sticker information is not needed.
public struct StickerItem: Codable, Hashable, Sendable {
    /// The sticker ID.
    public let id: StickerID
    
    /// The sticker name.
    public let name: String
    
    /// The sticker format type.
    public let format_type: Int
}

/// Represents a Discord sticker pack.
///
/// Sticker packs are collections of stickers that can be used across Discord.
///
/// ## Example
///
/// ```swift
/// let packs = try await client.getStickerPacks()
/// for pack in packs {
///     print("Pack: \(pack.name)")
///     print("Stickers: \(pack.stickers.count)")
/// }
/// ```
public struct StickerPack: Codable, Hashable, Sendable {
    /// The sticker pack ID.
    public let id: StickerPackID
    
    /// The stickers in this pack.
    public let stickers: [Sticker]
    
    /// The sticker pack name.
    public let name: String
    
    /// The SKU ID for this pack.
    public let sku_id: SKUID?
    
    /// The cover sticker ID.
    public let cover_sticker_id: StickerID?
    
    /// The sticker pack description.
    public let description: String?
    
    /// The banner asset ID.
    public let banner_asset_id: BannerAssetID?
}
