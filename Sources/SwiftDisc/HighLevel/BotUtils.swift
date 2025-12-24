import Foundation

// MARK: - Bot Utilities
public struct BotUtils {
    
    // MARK: - Message Formatting
    public struct MessageFormat {
        /// Escape Discord markdown special characters
        public static func escapeMarkdown(_ text: String) -> String {
            return text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "*", with: "\\*")
                .replacingOccurrences(of: "_", with: "\\_")
                .replacingOccurrences(of: "~", with: "\\~")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "|", with: "\\|")
                .replacingOccurrences(of: ">", with: "\\>")
        }
        
        /// Escape special characters for code blocks
        public static func escapeCodeBlock(_ text: String) -> String {
            return text.replacingOccurrences(of: "```", with: "´´´")
        }
        
        /// Format text as a code block with optional language
        public static func codeBlock(_ content: String, language: String? = nil) -> String {
            return "```\(language ?? "")\n\(content)\n```"
        }
        
        /// Format text as inline code
        public static func inlineCode(_ content: String) -> String {
            return "`\(content)`"
        }
        
        /// Create a bold text
        public static func bold(_ text: String) -> String {
            return "**\(text)**"
        }
        
        /// Create italic text
        public static func italic(_ text: String) -> String {
            return "*\(text)*"
        }
        
        /// Create underline text
        public static func underline(_ text: String) -> String {
            return "__\(text)__"
        }
        
        /// Create strikethrough text
        public static func strikethrough(_ text: String) -> String {
            return "~~\(text)~~"
        }
        
        /// Create a spoiler
        public static func spoiler(_ text: String) -> String {
            return "||\(text)||"
        }
        
        /// Create a quote block
        public static func quote(_ text: String) -> String {
            return "> \(text)"
        }
        
        /// Create a multi-line quote block
        public static func multiLineQuote(_ text: String) -> String {
            return ">>> \(text)"
        }
    }
    
    // MARK: - Message Splitting
    public struct MessageSplitter {
        private static let maxMessageLength = 2000
        
        /// Split a long message into chunks that fit Discord's message limit
        public static func splitMessage(_ message: String, maxLength: Int = maxMessageLength) -> [String] {
            if message.count <= maxLength {
                return [message]
            }
            
            var chunks: [String] = []
            var currentChunk = ""
            let lines = message.components(separatedBy: .newlines)
            
            for line in lines {
                if currentChunk.isEmpty && line.count > maxLength {
                    // Line itself is too long, split by words
                    chunks.append(contentsOf: splitLongLine(line, maxLength: maxLength))
                    continue
                }
                
                if (currentChunk + "\n" + line).count <= maxLength {
                    if !currentChunk.isEmpty {
                        currentChunk += "\n"
                    }
                    currentChunk += line
                } else {
                    chunks.append(currentChunk)
                    currentChunk = line
                }
            }
            
            if !currentChunk.isEmpty {
                chunks.append(currentChunk)
            }
            
            return chunks
        }
        
        private static func splitLongLine(_ line: String, maxLength: Int) -> [String] {
            var chunks: [String] = []
            var currentChunk = ""
            let words = line.components(separatedBy: " ")
            
            for word in words {
                if (currentChunk + " " + word).count <= maxLength {
                    if !currentChunk.isEmpty {
                        currentChunk += " "
                    }
                    currentChunk += word
                } else {
                    if !currentChunk.isEmpty {
                        chunks.append(currentChunk)
                    }
                    currentChunk = word
                }
            }
            
            if !currentChunk.isEmpty {
                chunks.append(currentChunk)
            }
            
            return chunks
        }
    }
    
    // MARK: - Time Utilities
    public struct TimeUtils {
        /// Get Discord timestamp for a given date and style
        public static func discordTimestamp(_ date: Date, style: TimestampStyle = .relative) -> String {
            return "<t:\(Int(date.timeIntervalSince1970)):\(style.rawValue)>"
        }
        
        public enum TimestampStyle: String {
            case shortTime = "t"
            case longTime = "T"
            case shortDate = "d"
            case longDate = "D"
            case shortDateTime = "f"
            case longDateTime = "F"
            case relative = "R"
        }
        
        /// Parse a Discord timestamp back to Date
        public static func parseDiscordTimestamp(_ timestamp: String) -> Date? {
            let pattern = "<t:(\\d+):[tTdDfFR]?>"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            
            let range = NSRange(location: 0, length: timestamp.utf16.count)
            guard let match = regex.firstMatch(in: timestamp, options: [], range: range) else { return nil }
            
            guard let timeRange = Range(match.range(at: 1), in: timestamp) else { return nil }
            let timeString = String(timestamp[timeRange])
            
            return Date(timeIntervalSince1970: TimeInterval(timeString) ?? 0)
        }
        
        /// Format duration in a human-readable way
        public static func formatDuration(_ seconds: TimeInterval) -> String {
            let duration = Int(seconds)
            let hours = duration / 3600
            let minutes = (duration % 3600) / 60
            let secs = duration % 60
            
            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, secs)
            } else {
                return String(format: "%02d:%02d", minutes, secs)
            }
        }
    }
    
    // MARK: - Validation Utilities
    public struct Validation {
        /// Validate if a string is a valid Discord username
        public static func isValidUsername(_ username: String) -> Bool {
            let usernameRegex = "^[\\w]{2,32}$"
            return NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: username)
        }
        
        /// Validate if a string is a valid Discord discriminator
        public static func isValidDiscriminator(_ discriminator: String) -> Bool {
            let discriminatorRegex = "^\\d{4}$"
            return NSPredicate(format: "SELF MATCHES %@", discriminatorRegex).evaluate(with: discriminator)
        }
        
        /// Validate if a string is a valid Discord tag (username#discriminator)
        public static func isValidDiscordTag(_ tag: String) -> Bool {
            let tagRegex = "^[\\w]{2,32}#\\d{4}$"
            return NSPredicate(format: "SELF MATCHES %@", tagRegex).evaluate(with: tag)
        }
        
        /// Validate if a string is a valid color hex code
        public static func isValidColorHex(_ hex: String) -> Bool {
            let colorRegex = "^#[0-9A-Fa-f]{6}$"
            return NSPredicate(format: "SELF MATCHES %@", colorRegex).evaluate(with: hex)
        }
        
        /// Validate if a string is a valid invite code
        public static func isValidInviteCode(_ code: String) -> Bool {
            let inviteRegex = "^[a-zA-Z0-9]{2,}$"
            return NSPredicate(format: "SELF MATCHES %@", inviteRegex).evaluate(with: code)
        }
    }
    
    // MARK: - Permission Helpers
    public struct PermissionHelpers {
        /// Check if a user has a specific permission in a channel
        public static func hasPermission(
            userId: UserID,
            permission: PermissionBitset,
            guildRoles: [Role],
            memberRoleIds: [RoleID],
            channel: Channel,
            everyoneRoleId: RoleID
        ) -> Bool {
            let effectivePerms = PermissionsUtil.effectivePermissions(
                userId: userId,
                memberRoleIds: memberRoleIds,
                guildRoles: guildRoles,
                channel: channel,
                everyoneRoleId: everyoneRoleId
            )
            
            return (effectivePerms & permission.rawValue) != 0
        }
        
        /// Check if a user is an administrator in a guild
        public static func isAdministrator(
            guildRoles: [Role],
            memberRoleIds: [RoleID]
        ) -> Bool {
            return guildRoles.contains { role in
                memberRoleIds.contains(role.id) && 
                (UInt64(role.permissions ?? "0") ?? 0) & PermissionBitset.administrator.rawValue != 0
            }
        }
        
        /// Get all permissions a user has in a channel as a PermissionBitset
        public static func getChannelPermissions(
            userId: UserID,
            guildRoles: [Role],
            memberRoleIds: [RoleID],
            channel: Channel,
            everyoneRoleId: RoleID
        ) -> PermissionBitset {
            let effectivePerms = PermissionsUtil.effectivePermissions(
                userId: userId,
                memberRoleIds: memberRoleIds,
                guildRoles: guildRoles,
                channel: channel,
                everyoneRoleId: everyoneRoleId
            )
            
            return PermissionBitset(rawValue: effectivePerms)
        }
    }
    
    // MARK: - Color Utilities
    public struct ColorUtils {
        /// Convert a hex color string to an integer
        public static func hexToInt(_ hex: String) -> Int? {
            let cleanHex = hex.replacingOccurrences(of: "#", with: "")
            return Int(cleanHex, radix: 16)
        }
        
        /// Convert an integer color to a hex string
        public static func intToHex(_ color: Int) -> String {
            return String(format: "#%06X", color)
        }
        
        /// Create a random color
        public static func randomColor() -> Int {
            return Int.random(in: 0...0xFFFFFF)
        }
        
        /// Get a contrasting text color (black or white) for a given background color
        public static func contrastingTextColor(for backgroundColor: Int) -> Int {
            let r = (backgroundColor >> 16) & 0xFF
            let g = (backgroundColor >> 8) & 0xFF
            let b = backgroundColor & 0xFF
            
            // Calculate luminance
            let luminance = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255
            
            return luminance > 0.5 ? 0x000000 : 0xFFFFFF
        }
    }
    
    // MARK: - Embed Builders
    public struct EmbedBuilder {
        public static func createEmbed(
            title: String? = nil,
            description: String? = nil,
            color: Int? = nil,
            url: String? = nil
        ) -> Embed {
            return Embed(
                title: title,
                description: description,
                url: url,
                color: color,
                timestamp: nil,
                footer: nil,
                image: nil,
                thumbnail: nil,
                video: nil,
                provider: nil,
                author: nil,
                fields: nil
            )
        }
        
        public static func addField(
            to embed: inout Embed,
            name: String,
            value: String,
            inline: Bool = false
        ) {
            if embed.fields == nil {
                embed.fields = []
            }
            embed.fields?.append(Embed.Field(name: name, value: value, inline: inline))
        }
        
        public static func setFooter(
            to embed: inout Embed,
            text: String,
            iconUrl: String? = nil,
            proxyIconUrl: String? = nil
        ) {
            embed.footer = Embed.Footer(text: text, icon_url: iconUrl, proxy_icon_url: proxyIconUrl)
        }
        
        public static func setAuthor(
            to embed: inout Embed,
            name: String,
            url: String? = nil,
            iconUrl: String? = nil,
            proxyIconUrl: String? = nil
        ) {
            embed.author = Embed.Author(name: name, url: url, icon_url: iconUrl, proxy_icon_url: proxyIconUrl)
        }
        
        public static func setImage(
            to embed: inout Embed,
            url: String,
            proxyUrl: String? = nil,
            height: Int? = nil,
            width: Int? = nil
        ) {
            embed.image = Embed.Image(url: url, proxy_url: proxyUrl, height: height, width: width)
        }
        
        public static func setThumbnail(
            to embed: inout Embed,
            url: String,
            proxyUrl: String? = nil,
            height: Int? = nil,
            width: Int? = nil
        ) {
            embed.thumbnail = Embed.Thumbnail(url: url, proxy_url: proxyUrl, height: height, width: width)
        }
    }
}
