import Foundation

/// A collection of static utilities for common bot development tasks.
public enum BotUtils {
    /// Splits a long string into Discord-safe message chunks.
    ///
    /// Discord enforces a 2000-character message limit. This function splits content
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
    
    /// Extracts role mentions from a message string.
    ///
    /// Parses `<@&roleID>` mention format.
    ///
    /// - Parameter content: The message text to scan.
    /// - Returns: An array of role ID strings found in the content.
    public static func extractRoleMentions(_ content: String) -> [String] {
        let pattern = #"<@&([0-9]{5,})>"#
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
    
    /// Extracts channel mentions from a message string.
    ///
    /// Parses `<#channelID>` mention format.
    ///
    /// - Parameter content: The message text to scan.
    /// - Returns: An array of channel ID strings found in the content.
    public static func extractChannelMentions(_ content: String) -> [String] {
        let pattern = #"<#([0-9]{5,})>"#
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
    
    /// Removes all Discord mentions from a string.
    ///
    /// - Parameter content: The message text to sanitize.
    /// - Returns: The content with all mentions removed.
    public static func stripMentions(_ content: String) -> String {
        var result = content
        result = result.replacingOccurrences(of: #"<@!?[0-9]{5,}>"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"<@&[0-9]{5,}>"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"<#[0-9]{5,}>"#, with: "", options: .regularExpression)
        return result
    }
    
    /// Truncates a string to a maximum length with an ellipsis if needed.
    ///
    /// - Parameters:
    ///   - text: The text to truncate.
    ///   - maxLength: Maximum length before truncation.
    ///   - suffix: String to append when truncated (defaults to "...").
    /// - Returns: The truncated string.
    public static func truncate(_ text: String, maxLength: Int, suffix: String = "...") -> String {
        if text.count <= maxLength { return text }
        let truncated = String(text.prefix(maxLength - suffix.count))
        return truncated + suffix
    }
    
    /// Escapes Discord markdown formatting in a string.
    ///
    /// - Parameter text: The text to escape.
    /// - Returns: The text with markdown characters escaped.
    public static func escapeMarkdown(_ text: String) -> String {
        var result = text
        let specialChars = ["\\", "*", "_", "~", "|", "`", ">", ":", "@"]
        for char in specialChars {
            result = result.replacingOccurrences(of: char, with: "\\\(char)")
        }
        return result
    }
    
    /// Formats a relative timestamp in a human-readable way.
    ///
    /// - Parameters:
    ///   - date: The date to format.
    ///   - relativeTo: The reference date (defaults to now).
    /// - Returns: A string like "2 hours ago" or "in 3 days".
    public static func formatRelativeTime(_ date: Date, relativeTo: Date = Date()) -> String {
        let interval = date.timeIntervalSince(relativeTo)
        let absInterval = abs(interval)
        
        if absInterval < 60 {
            return interval < 0 ? "just now" : "just now"
        } else if absInterval < 3600 {
            let minutes = Int(absInterval / 60)
            return interval < 0 ? "\(minutes)m ago" : "in \(minutes)m"
        } else if absInterval < 86400 {
            let hours = Int(absInterval / 3600)
            return interval < 0 ? "\(hours)h ago" : "in \(hours)h"
        } else if absInterval < 604800 {
            let days = Int(absInterval / 86400)
            return interval < 0 ? "\(days)d ago" : "in \(days)d"
        } else {
            let weeks = Int(absInterval / 604800)
            return interval < 0 ? "\(weeks)w ago" : "in \(weeks)w"
        }
    }
    
    /// Generates a random string of specified length.
    ///
    /// - Parameters:
    ///   - length: The length of the random string.
    ///   - charset: Characters to use (defaults to alphanumeric).
    /// - Returns: A random string.
    public static func randomString(length: Int, charset: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") -> String {
        return String((0..<length).map { _ in charset.randomElement()! })
    }
}
