import Foundation

/// A fluent builder for `Embed` objects.
public struct EmbedBuilder {
    private var title: String?
    private var description: String?
    private var url: String?
    private var color: Int?
    private var footer: Embed.Footer?
    private var author: Embed.Author?
    private var fields: [Embed.Field] = []
    private var thumbnail: Embed.Image?
    private var image: Embed.Image?
    private var timestamp: String?

    public init() {}

    public mutating func title(_ t: String) -> EmbedBuilder { var c = self; c.title = t; return c }
    public mutating func description(_ d: String) -> EmbedBuilder { var c = self; c.description = d; return c }
    public mutating func url(_ u: String) -> EmbedBuilder { var c = self; c.url = u; return c }
    public mutating func color(_ cval: Int) -> EmbedBuilder { var c = self; c.color = cval; return c }
    public mutating func footer(text: String, iconURL: String? = nil) -> EmbedBuilder { var c = self; c.footer = .init(text: text, icon_url: iconURL); return c }
    public mutating func author(name: String, url: String? = nil, iconURL: String? = nil) -> EmbedBuilder { var c = self; c.author = .init(name: name, url: url, icon_url: iconURL); return c }
    public mutating func addField(name: String, value: String, inline: Bool = false) -> EmbedBuilder { var c = self; c.fields.append(.init(name: name, value: value, inline: inline)); return c }
    public mutating func thumbnail(url: String) -> EmbedBuilder { var c = self; c.thumbnail = .init(url: url); return c }
    public mutating func image(url: String) -> EmbedBuilder { var c = self; c.image = .init(url: url); return c }
    public mutating func timestamp(_ iso8601: String) -> EmbedBuilder { var c = self; c.timestamp = iso8601; return c }

    public func build() -> Embed {
        return Embed(title: title, description: description, url: url, color: color, footer: footer, author: author, fields: fields.isEmpty ? nil : fields, thumbnail: thumbnail, image: image, timestamp: timestamp)
    }
}
