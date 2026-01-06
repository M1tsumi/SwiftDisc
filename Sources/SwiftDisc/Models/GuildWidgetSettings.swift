//
//  GuildWidgetSettings.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct GuildWidgetSettings: Codable, Hashable {
    public let enabled: Bool
    public let channel_id: ChannelID?
}
