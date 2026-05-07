import Foundation

/// Converter utilities for common command argument types.
public enum Converters: Sendable {
    // MARK: - Snowflake Parsing
    
    /// Parse a raw argument as a Snowflake<T> by accepting plain ids or mention forms like `<@1234>` or `<@!1234>`.
    public static func parseSnowflake<T>(_ raw: String) -> Snowflake<T>? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        // Mention forms: <@123>, <@!123>, <#123>, <@&123>
        if trimmed.first == "<", trimmed.last == ">" {
            // strip < and >
            let inner = String(trimmed.dropFirst().dropLast())
            // possible prefixes @, @!, #, @&
            let digits = inner.filter { $0.isNumber }
            return digits.isEmpty ? nil : Snowflake<T>(digits)
        }

        // plain id
        let digits = trimmed.filter { $0.isNumber }
        return digits.isEmpty ? nil : Snowflake<T>(digits)
    }

    /// Parse a channel mention `<#id>` into `ChannelID`.
    public static func parseChannelId(_ raw: String) -> ChannelID? {
        return parseSnowflake(raw)
    }

    /// Parse a user mention into `UserID`.
    public static func parseUserId(_ raw: String) -> UserID? {
        return parseSnowflake(raw)
    }

    /// Parse a role mention into `RoleID`.
    public static func parseRoleId(_ raw: String) -> RoleID? {
        return parseSnowflake(raw)
    }
    
    // MARK: - Timestamp Conversion
    
    /// Convert a Discord snowflake ID to a Unix timestamp (milliseconds since epoch).
    /// Discord snowflake IDs contain timestamp information in the upper bits.
    public static func snowflakeToTimestamp<T>(_ id: Snowflake<T>) -> Date {
        // Discord epoch: first second of 2015 (1420070400000)
        let discordEpoch: UInt64 = 1420070400000
        guard let raw = UInt64(id.rawValue) else { return Date(timeIntervalSince1970: 0) }
        let timestamp = (raw >> 22) + discordEpoch
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }
    
    /// Format a Date as an ISO8601 string suitable for Discord.
    public static func formatDateAsISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    /// Parse an ISO8601 string to a Date.
    public static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
    
    /// Convert a duration string (e.g., "1h30m", "45s", "2d") to seconds.
    /// Supported units: s (seconds), m (minutes), h (hours), d (days)
    public static func parseDuration(_ duration: String) -> TimeInterval? {
        var total: TimeInterval = 0
        var current: String = ""
        
        for char in duration {
            if char.isNumber {
                current.append(char)
            } else {
                guard let value = TimeInterval(current) else { return nil }
                switch char.lowercased() {
                case "s": total += value
                case "m": total += value * 60
                case "h": total += value * 3600
                case "d": total += value * 86400
                default: return nil
                }
                current = ""
            }
        }
        return total > 0 ? total : nil
    }
    
    // MARK: - Color Conversion
    
    /// Convert a hex color string (e.g., "5865F2" or "#5865F2") to an integer.
    public static func hexToInt(_ hex: String) -> Int? {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        return Int(cleaned, radix: 16)
    }
    
    /// Convert an integer color to a hex string (without #).
    public static func intToHex(_ color: Int) -> String {
        return String(format: "%06X", color)
    }
    
    /// Discord Blurple color
    public static let discordBlurple: Int = 0x5865F2
    /// Discord green color
    public static let discordGreen: Int = 0x57F287
    /// Discord red color
    public static let discordRed: Int = 0xED4245
    /// Discord yellow color
    public static let discordYellow: Int = 0xFEE75C
    /// Discord orange color
    public static let discordOrange: Int = 0xEB459E
    
    // MARK: - Emoji Parsing
    
    /// Extract emoji name from custom emoji format (e.g., ":emoji_name:" -> "emoji_name")
    public static func parseEmojiName(_ emoji: String) -> String? {
        guard emoji.hasPrefix(":") && emoji.hasSuffix(":") else { return nil }
        return String(emoji.dropFirst().dropLast())
    }
    
    /// Extract emoji ID from animated/animated custom emoji format (e.g., "<a:emoji_name:123>" -> "123")
    public static func parseEmojiId(_ emoji: String) -> String? {
        guard emoji.hasPrefix("<") && emoji.hasSuffix(">") else { return nil }
        let inner = String(emoji.dropFirst().dropLast())
        let parts = inner.split(separator: ":")
        guard parts.count >= 3 else { return nil }
        return String(parts[2])
    }
    
    /// Check if a string is a custom emoji (animated or not).
    public static func isCustomEmoji(_ emoji: String) -> Bool {
        return emoji.hasPrefix("<") && emoji.hasSuffix(">")
    }
    
    // MARK: - URL Validation
    
    /// Validate a URL string.
    public static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    /// Validate a Discord invite code.
    public static func isValidInviteCode(_ code: String) -> Bool {
        // Discord invite codes are typically alphanumeric, 6-10 characters
        let pattern = "^[a-zA-Z0-9]{6,10}$"
        return code.range(of: pattern, options: .regularExpression) != nil
    }
}
