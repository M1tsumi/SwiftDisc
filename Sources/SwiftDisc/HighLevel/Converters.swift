//
//  Converters.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Converter utilities for common command argument types.
public enum Converters {
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
}
