import Foundation

/// Helpers for building Discord mention strings.
///
/// Discord renders mentions using a tag-like syntax that the client resolves
/// at display time. Use these helpers instead of hand-formatting strings to
/// avoid subtle bugs (for example, omitting the `&` prefix on role mentions).
///
/// ## Example
/// ```swift
/// let greeting = "Welcome \(Mentions.user(member.id)) to \(Mentions.channel(channelId))!"
/// ```
public enum Mentions: Sendable {
    /// A user mention: `<@id>`.
    public static func user(_ id: CustomStringConvertible) -> String { "<@\(id)>" }

    /// A user mention with the legacy nickname marker: `<@!id>`.
    ///
    /// Modern Discord clients render nickname and plain user mentions
    /// identically. Prefer ``user(_:)`` for new code.
    public static func userNickname(_ id: CustomStringConvertible) -> String { "<@!\(id)>" }

    /// A channel mention: `<#id>`.
    public static func channel(_ id: CustomStringConvertible) -> String { "<#\(id)>" }

    /// A role mention: `<@&id>`.
    public static func role(_ id: CustomStringConvertible) -> String { "<@&\(id)>" }

    /// A clickable slash-command mention: `</name:id>`.
    ///
    /// - Parameters:
    ///   - name: The command name (without the leading slash). Subcommand
    ///     groups must be space-separated, e.g. `"settings update"`.
    ///   - id: The application command ID returned when the command was
    ///     registered.
    public static func slashCommand(name: String, id: CustomStringConvertible) -> String { "</\(name):\(id)>" }
}

/// Helpers for formatting custom emoji strings.
///
/// Custom emojis are rendered using a tag that includes the emoji name and
/// snowflake ID. Animated emojis use a different prefix.
///
/// ## Example
/// ```swift
/// let reaction = EmojiUtils.custom(name: "party", id: emojiId, animated: true)
/// ```
public enum EmojiUtils: Sendable {
    /// Builds the tag for a custom emoji.
    ///
    /// - Parameters:
    ///   - name: The emoji's name as registered in the guild.
    ///   - id: The emoji ID.
    ///   - animated: Pass `true` for animated emojis (`<a:name:id>`),
    ///     `false` for static (`<:name:id>`).
    public static func custom(name: String, id: CustomStringConvertible, animated: Bool = false) -> String {
        animated ? "<a:\(name):\(id)>" : "<:\(name):\(id)>"
    }
}

/// Display styles for Discord timestamp tags.
///
/// Discord renders timestamps using each viewer's locale, so the same tag can
/// appear differently across clients. Comments below show the typical
/// rendering for an English locale.
public enum TimestampStyle: String, Sendable {
    /// Short time, e.g. `16:20`.
    case shortTime = "t"
    /// Long time, e.g. `16:20:30`.
    case longTime = "T"
    /// Short date, e.g. `20/04/2021`.
    case shortDate = "d"
    /// Long date, e.g. `20 April 2021`.
    case longDate = "D"
    /// Short date and time, e.g. `20 April 2021 16:20`.
    case shortDateTime = "f"
    /// Long date and time, e.g. `Tuesday, 20 April 2021 16:20`.
    case longDateTime = "F"
    /// Relative time, e.g. `in 2 months`.
    case relativeTime = "R"
}

/// Helpers for building Discord timestamp tags.
///
/// Timestamps are rendered client-side in each viewer's local timezone.
///
/// ## Example
/// ```swift
/// let banner = "Maintenance starts \(DiscordTimestamp.format(date: start, style: .relativeTime))."
/// ```
public enum DiscordTimestamp: Sendable {
    /// Builds a timestamp tag for the given `Date`.
    ///
    /// - Parameters:
    ///   - date: The instant to render. Defaults to the current time.
    ///   - style: The display style. Defaults to ``TimestampStyle/shortDateTime``.
    /// - Returns: A `<t:seconds:style>` tag.
    public static func format(date: Date = Date(), style: TimestampStyle = .shortDateTime) -> String {
        let seconds = Int(date.timeIntervalSince1970)
        return "<t:\(seconds):\(style.rawValue)>"
    }

    /// Builds a timestamp tag from a Unix epoch in seconds.
    ///
    /// - Parameters:
    ///   - unixSeconds: Seconds since 1970-01-01 UTC.
    ///   - style: The display style. Defaults to ``TimestampStyle/shortDateTime``.
    /// - Returns: A `<t:seconds:style>` tag.
    public static func format(unixSeconds: Int, style: TimestampStyle = .shortDateTime) -> String {
        "<t:\(unixSeconds):\(style.rawValue)>"
    }
}

/// Helpers for working with Discord's markdown.
///
/// Use this when including untrusted user input in a message that should be
/// rendered as plain text rather than markdown.
public enum MessageFormat: Sendable {
    /// Escapes characters that Discord's markdown parser treats specially.
    ///
    /// Discord's markdown metacharacters are: `\`, `*`, `_`, `~`, `|`, `>`, `` ` ``, `#`.
    /// Backslash is escaped first to avoid double-escaping later replacements.
    ///
    /// - Parameter input: Raw text that may contain markdown metacharacters.
    /// - Returns: A string safe to embed in a Discord message body without
    ///   triggering markdown formatting.
    public static func escapeSpecialCharacters(_ input: String) -> String {
        // Order matters to avoid double-escaping
        var out = input
        let replacements: [(String, String)] = [
            ("\\", "\\\\"),
            ("*", "\\*"),
            ("_", "\\_"),
            ("`", "\\`"),
            ("~", "\\~"),
            ("|", "\\|"),
            (">", "\\>"),
            ("#", "\\#")
        ]
        for (from, to) in replacements { out = out.replacingOccurrences(of: from, with: to) }
        return out
    }
}
