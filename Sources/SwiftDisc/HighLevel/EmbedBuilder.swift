import Foundation

/// A fluent, value-type builder for Discord `Embed` objects.
///
/// Chain builder methods to compose an embed, then call ``build()`` to produce
/// the final `Embed` value ready for sending.
///
/// ```swift
/// let embed = EmbedBuilder()
///     .title("Server Status")
///     .description("All systems operational.")
///     .color(0x57F287)
///     .footer(text: "Last checked")
///     .timestamp(Date())
///     .build()
/// ```
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

    /// Creates a new, empty `EmbedBuilder`.
    public init() {}

    /// Sets the embed title.
    /// - Parameter t: The title text (max 256 characters per Discord API limits).
    /// - Returns: A new builder with the title applied.
    public func title(_ t: String) -> EmbedBuilder { var c = self; c.title = t; return c }

    /// Sets the embed description body text.
    /// - Parameter d: The description text (max 4096 characters per Discord API limits).
    /// - Returns: A new builder with the description applied.
    public func description(_ d: String) -> EmbedBuilder { var c = self; c.description = d; return c }

    /// Sets the URL the embed title links to when clicked.
    /// - Parameter u: A valid URL string.
    /// - Returns: A new builder with the URL applied.
    public func url(_ u: String) -> EmbedBuilder { var c = self; c.url = u; return c }

    /// Sets the embed's left-border accent color.
    /// - Parameter cval: An RGB integer (e.g. `0x5865F2` for Discord Blurple, `0x57F287` for green).
    /// - Returns: A new builder with the color applied.
    public func color(_ cval: Int) -> EmbedBuilder { var c = self; c.color = cval; return c }

    /// Sets the embed footer displayed at the bottom of the embed.
    /// - Parameters:
    ///   - text: Footer text (max 2048 characters).
    ///   - iconURL: Optional direct URL for a small icon displayed beside the footer text.
    /// - Returns: A new builder with the footer applied.
    public func footer(text: String, iconURL: String? = nil) -> EmbedBuilder {
        var c = self; c.footer = .init(text: text, icon_url: iconURL); return c
    }

    /// Sets the embed author block displayed above the title.
    /// - Parameters:
    ///   - name: The author's display name (max 256 characters).
    ///   - url: Optional URL the author name links to when clicked.
    ///   - iconURL: Optional direct URL for a small icon displayed beside the author name.
    /// - Returns: A new builder with the author applied.
    public func author(name: String, url: String? = nil, iconURL: String? = nil) -> EmbedBuilder {
        var c = self; c.author = .init(name: name, url: url, icon_url: iconURL); return c
    }

    /// Appends a field to the embed.
    ///
    /// Discord renders up to 25 fields per embed. Adjacent inline fields are grouped
    /// side-by-side in rows of up to three.
    ///
    /// - Parameters:
    ///   - name: The field heading (max 256 characters, required).
    ///   - value: The field body text (max 1024 characters, required).
    ///   - inline: When `true`, Discord renders this field side-by-side with adjacent inline fields.
    /// - Returns: A new builder with the field appended.
    public func addField(name: String, value: String, inline: Bool = false) -> EmbedBuilder {
        var c = self; c.fields.append(.init(name: name, value: value, inline: inline)); return c
    }

    /// Sets the embed thumbnail — a small image displayed in the top-right corner.
    /// - Parameter url: A direct URL to the thumbnail image.
    /// - Returns: A new builder with the thumbnail applied.
    public func thumbnail(url: String) -> EmbedBuilder {
        var c = self; c.thumbnail = .init(url: url); return c
    }

    /// Sets the embed's main large image, displayed below the description and fields.
    /// - Parameter url: A direct URL to the image.
    /// - Returns: A new builder with the image applied.
    public func image(url: String) -> EmbedBuilder {
        var c = self; c.image = .init(url: url); return c
    }

    /// Sets the embed timestamp from a pre-formatted ISO 8601 string.
    ///
    /// Prefer the `timestamp(_:)` overload that accepts a `Date` when working with
    /// Swift date values, as it handles formatting automatically.
    ///
    /// - Parameter iso8601: An ISO 8601 date-time string, e.g. `"2026-03-05T12:00:00.000Z"`.
    /// - Returns: A new builder with the timestamp applied.
    public func timestamp(_ iso8601: String) -> EmbedBuilder {
        var c = self; c.timestamp = iso8601; return c
    }

    /// Sets the embed timestamp from a `Date`, automatically formatting it as ISO 8601.
    ///
    /// Discord displays this timestamp in the user's local timezone with relative
    /// hover text (e.g. "3 hours ago").
    ///
    /// - Parameter date: The date to display. Pass `Date()` for the current moment.
    /// - Returns: A new builder with the timestamp applied.
    public func timestamp(_ date: Date) -> EmbedBuilder {
        var c = self
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        c.timestamp = formatter.string(from: date)
        return c
    }

    /// Finalizes the builder and returns the composed `Embed`.
    ///
    /// The returned value is ready to be passed to any Discord API method that
    /// accepts embeds, such as `DiscordClient.sendMessage(channelId:embeds:)`.
    ///
    /// - Returns: A fully composed `Embed` value.
    public func build() -> Embed {
        return Embed(
            title: title,
            description: description,
            url: url,
            color: color,
            footer: footer,
            author: author,
            fields: fields.isEmpty ? nil : fields,
            thumbnail: thumbnail,
            image: image,
            timestamp: timestamp
        )
    }
    
    /// Validates the embed against Discord API limits.
    /// - Throws: ValidationError if any limits are exceeded
    public func validate() throws {
        if let title = title, title.count > 256 {
            throw ValidationError.titleTooLong(length: title.count, max: 256)
        }
        if let description = description, description.count > 4096 {
            throw ValidationError.descriptionTooLong(length: description.count, max: 4096)
        }
        if fields.count > 25 {
            throw ValidationError.tooManyFields(count: fields.count, max: 25)
        }
        for (index, field) in fields.enumerated() {
            if field.name.count > 256 {
                throw ValidationError.fieldNameTooLong(field: index, length: field.name.count, max: 256)
            }
            if field.value.count > 1024 {
                throw ValidationError.fieldValueTooLong(field: index, length: field.value.count, max: 1024)
            }
        }
    }
    
    /// Builds and validates the embed.
    /// - Throws: ValidationError if any limits are exceeded
    /// - Returns: A fully composed `Embed` value
    public func buildAndValidate() throws -> Embed {
        try validate()
        return build()
    }
    
    public enum ValidationError: Error, LocalizedDescription {
        case titleTooLong(length: Int, max: Int)
        case descriptionTooLong(length: Int, max: Int)
        case tooManyFields(count: Int, max: Int)
        case fieldNameTooLong(field: Int, length: Int, max: Int)
        case fieldValueTooLong(field: Int, length: Int, max: Int)
        
        public var errorDescription: String? {
            switch self {
            case .titleTooLong(let length, let max):
                return "Embed title too long: \(length) characters (max \(max))"
            case .descriptionTooLong(let length, let max):
                return "Embed description too long: \(length) characters (max \(max))"
            case .tooManyFields(let count, let max):
                return "Too many embed fields: \(count) (max \(max))"
            case .fieldNameTooLong(let field, let length, let max):
                return "Embed field \(field) name too long: \(length) characters (max \(max))"
            case .fieldValueTooLong(let field, let length, let max):
                return "Embed field \(field) value too long: \(length) characters (max \(max))"
            }
        }
    }
}
