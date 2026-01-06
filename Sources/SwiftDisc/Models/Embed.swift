//
//  Embed.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Embed: Codable, Hashable {
    public struct Footer: Codable, Hashable { public let text: String; public let icon_url: String? }
    public struct Author: Codable, Hashable { public let name: String; public let url: String?; public let icon_url: String? }
    public struct Field: Codable, Hashable { public let name: String; public let value: String; public let inline: Bool? }
    public let title: String?
    public let description: String?
    public let url: String?
    public let color: Int?
    public let footer: Footer?
    public let author: Author?
    public let fields: [Field]?
    public let thumbnail: Image?
    public let image: Image?
    public let timestamp: String?

    public struct Image: Codable, Hashable { public let url: String }

    public init(title: String? = nil, description: String? = nil, url: String? = nil, color: Int? = nil, footer: Footer? = nil, author: Author? = nil, fields: [Field]? = nil, thumbnail: Image? = nil, image: Image? = nil, timestamp: String? = nil) {
        self.title = title
        self.description = description
        self.url = url
        self.color = color
        self.footer = footer
        self.author = author
        self.fields = fields
        self.thumbnail = thumbnail
        self.image = image
        self.timestamp = timestamp
    }
}
