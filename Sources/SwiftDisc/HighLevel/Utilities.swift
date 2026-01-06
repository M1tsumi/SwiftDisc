//
//  Utilities.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public enum BotUtils {
    // Splits content into Discord-safe chunks (approx 2000 chars)
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

    // Returns true if message starts with any of the provided prefixes
    public static func hasPrefix(_ content: String, prefixes: [String]) -> Bool {
        for p in prefixes where content.hasPrefix(p) { return true }
        return false
    }

    // Extract user mentions in <@id> or <@!id> format
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

    public static func mentionsBot(_ content: String, botId: String) -> Bool {
        extractMentions(content).contains(botId)
    }
}
