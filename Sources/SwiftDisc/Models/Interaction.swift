//
//  Interaction.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Interaction: Codable, Hashable {
    public let id: InteractionID
    public let application_id: ApplicationID
    public let type: Int
    public let token: String
    public let channel_id: ChannelID?
    public let guild_id: GuildID?

    public struct ApplicationCommandData: Codable, Hashable {
        public struct Option: Codable, Hashable {
            public let name: String
            public let type: Int?
            public let value: String?
            public let options: [Option]?
            public let focused: Bool?
        }
        public let id: InteractionID?
        public let name: String
        public let type: Int?
        public let options: [Option]?
        // Component interaction fields (optional): `custom_id` for buttons/selects, `component_type` and `values` for select menus.
        public let custom_id: String?
        public let component_type: Int?
        public let values: [String]?
    }
    public let data: ApplicationCommandData?
}
