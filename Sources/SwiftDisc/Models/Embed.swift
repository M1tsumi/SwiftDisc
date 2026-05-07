import Foundation

public struct Embed: Codable, Hashable, Sendable {
    public struct Footer: Codable, Hashable, Sendable {
        public let text: String
        public let icon_url: String?
        public let proxy_icon_url: String?
        public init(text: String, icon_url: String? = nil, proxy_icon_url: String? = nil) {
            self.text = text
            self.icon_url = icon_url
            self.proxy_icon_url = proxy_icon_url
        }
    }
    public struct Author: Codable, Hashable, Sendable {
        public let name: String
        public let url: String?
        public let icon_url: String?
        public init(name: String, url: String? = nil, icon_url: String? = nil) {
            self.name = name
            self.url = url
            self.icon_url = icon_url
        }
    }
    public struct Field: Codable, Hashable, Sendable {
        public let name: String
        public let value: String
        public let inline: Bool?
        public init(name: String, value: String, inline: Bool? = nil) {
            self.name = name
            self.value = value
            self.inline = inline
        }
    }
    public struct Video: Codable, Hashable, Sendable {
        public let url: String?
        public let proxy_url: String?
        public let height: Int?
        public let width: Int?
        public init(url: String? = nil, proxy_url: String? = nil, height: Int? = nil, width: Int? = nil) {
            self.url = url
            self.proxy_url = proxy_url
            self.height = height
            self.width = width
        }
    }
    public let title: String?
    public let description: String?
    public let url: String?
    public let color: Int?
    public let footer: Footer?
    public let author: Author?
    public let fields: [Field]?
    public let thumbnail: Image?
    public let image: Image?
    public let video: Video?
    public let provider: Provider?
    public let timestamp: String?

    public struct Image: Codable, Hashable, Sendable {
        public let url: String?
        public let proxy_url: String?
        public let height: Int?
        public let width: Int?
        public init(url: String? = nil, proxy_url: String? = nil, height: Int? = nil, width: Int? = nil) {
            self.url = url
            self.proxy_url = proxy_url
            self.height = height
            self.width = width
        }
    }
    public struct Provider: Codable, Hashable, Sendable {
        public let name: String?
        public let url: String?
        public init(name: String? = nil, url: String? = nil) {
            self.name = name
            self.url = url
        }
    }

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
