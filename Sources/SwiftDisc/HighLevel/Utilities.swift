import Foundation

/// A collection of static utility helpers for common bot development tasks.
public enum BotUtils {
    /// Splits a long string into Discord-safe message chunks.
    ///
    /// Discord enforces a 2000-character message limit. This helper splits content
    /// on newline boundaries to avoid cutting words mid-line while keeping each
    /// chunk within the specified `maxLength`.
    ///
    /// - Parameters:
    ///   - content: The full text to split.
    ///   - maxLength: Maximum character length per chunk. Defaults to `1900` to leave
    ///     headroom for prefixes or suffixes your bot may append.
    /// - Returns: An array of strings, each at most `maxLength` characters long.
    public static func chunkMessage(_ content: String, maxLength: Int = 1900) -> [String] {
        guard content.count > maxLength else { return [content] }
        var chunks: [String] = []
        var current = ""
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            if current.count + line.count + 1 > maxLength {
                if !current.isEmpty { chunks.append(current) }
                current = String(line)
            } else {
                if current.isEmpty { current = String(line) }
                else { current += "\n" + line }
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    /// Returns `true` if the message content begins with any of the provided prefix strings.
    ///
    /// Useful for multi-prefix bots that support more than one command trigger character.
    ///
    /// - Parameters:
    ///   - content: The message text to check.
    ///   - prefixes: An array of prefix strings to test against.
    /// - Returns: `true` if `content` starts with at least one of the given prefixes.
    public static func hasPrefix(_ content: String, prefixes: [String]) -> Bool {
        for p in prefixes where content.hasPrefix(p) { return true }
        return false
    }

    /// Extracts user IDs from Discord mention tags embedded in a message string.
    ///
    /// Parses both `<@userID>` and legacy `<@!userID>` mention formats.
    ///
    /// - Parameter content: The message text to scan.
    /// - Returns: An array of user ID strings found in the content, in order of appearance.
    public static func extractMentions(_ content: String) -> [String] {
        let pattern = #"<@!?([0-9]{5,})>"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(location: 0, length: content.utf16.count)
        var ids: [String] = []
        re.enumerateMatches(in: content, options: [], range: range) { m, _, _ in
            if let m = m, m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: content) {
                ids.append(String(content[r]))
            }
        }
        return ids
    }

    /// Returns `true` if the message content contains a mention of the given bot user ID.
    ///
    /// - Parameters:
    ///   - content: The message text to check.
    ///   - botId: The bot's user ID as a string.
    /// - Returns: `true` if a mention matching `botId` appears anywhere in `content`.
    public static func mentionsBot(_ content: String, botId: String) -> Bool {
        extractMentions(content).contains(botId)
    }
}
