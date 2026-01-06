//
//  Sticker.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Sticker: Codable, Hashable {
    public let id: StickerID
    public let name: String
    public let description: String?
    public let tags: String?
    public let type: Int?
    public let format_type: Int?
    public let available: Bool?
    public let guild_id: GuildID?
}

public struct StickerItem: Codable, Hashable {
    public let id: StickerID
    public let name: String
    public let format_type: Int
}

public struct StickerPack: Codable, Hashable {
    public let id: StickerPackID
    public let stickers: [Sticker]
    public let name: String
    public let sku_id: SKUID?
    public let cover_sticker_id: StickerID?
    public let description: String?
    public let banner_asset_id: BannerAssetID?
}
