//
//  DiscordUtils.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public enum Mentions {
    public static func user(_ id: CustomStringConvertible) -> String { "<@\(id)>" }
    public static func userNickname(_ id: CustomStringConvertible) -> String { "<@!\(id)>" }
    public static func channel(_ id: CustomStringConvertible) -> String { "<#\(id)>" }
    public static func role(_ id: CustomStringConvertible) -> String { "<@&\(id)>" }
    public static func slashCommand(name: String, id: CustomStringConvertible) -> String { "</\(name):\(id)>" }
}

public enum EmojiUtils {
    public static func custom(name: String, id: CustomStringConvertible, animated: Bool = false) -> String {
        animated ? "<a:\(name):\(id)>" : "<:\(name):\(id)>"
    }
}

public enum TimestampStyle: String {
    case shortTime = "t"      // 16:20
    case longTime = "T"       // 16:20:30
    case shortDate = "d"      // 20/04/2021
    case longDate = "D"       // 20 April 2021
    case shortDateTime = "f"  // 20 April 2021 16:20
    case longDateTime = "F"   // Tuesday, 20 April 2021 16:20
    case relativeTime = "R"   // in 2 months
}

public enum DiscordTimestamp {
    public static func format(date: Date = Date(), style: TimestampStyle = .shortDateTime) -> String {
        let seconds = Int(date.timeIntervalSince1970)
        return "<t:\(seconds):\(style.rawValue)>"
    }

    public static func format(unixSeconds: Int, style: TimestampStyle = .shortDateTime) -> String {
        "<t:\(unixSeconds):\(style.rawValue)>"
    }
}

public enum MessageFormat {
    /// Escapes Discord markdown special characters in a user-provided string
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
            ("(", "\\("),
            (")", "\\)"),
            ("[", "\\["),
            ("]", "\\]"),
            ("{", "\\{"),
            ("}", "\\}"),
            ("#", "\\#"),
            ("+", "\\+"),
            ("-", "\\-"),
            ("=", "\\="),
            (".", "\\."),
            ("!", "\\!")
        ]
        for (from, to) in replacements { out = out.replacingOccurrences(of: from, with: to) }
        return out
    }
}
