//
//  ApplicationRoleConnection.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct ApplicationRoleConnection: Codable, Hashable {
    public let platformName: String?
    public let platformUsername: String?
    public let metadata: [String: String]
    
    public init(platformName: String? = nil, platformUsername: String? = nil, metadata: [String: String] = [:]) {
        self.platformName = platformName
        self.platformUsername = platformUsername
        self.metadata = metadata
    }
    
    private enum CodingKeys: String, CodingKey {
        case platformName = "platform_name"
        case platformUsername = "platform_username"
        case metadata
    }
}

public struct ApplicationRoleConnectionMetadata: Codable, Hashable {
    public let type: RoleConnectionMetadataType
    public let key: String
    public let name: String
    public let description: String
    public let nameLocalizations: [String: String]?
    public let descriptionLocalizations: [String: String]?
    
    public init(type: RoleConnectionMetadataType, key: String, name: String, description: String, nameLocalizations: [String: String]? = nil, descriptionLocalizations: [String: String]? = nil) {
        self.type = type
        self.key = key
        self.name = name
        self.description = description
        self.nameLocalizations = nameLocalizations
        self.descriptionLocalizations = descriptionLocalizations
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, key, name, description
        case nameLocalizations = "name_localizations"
        case descriptionLocalizations = "description_localizations"
    }
}

public enum RoleConnectionMetadataType: Int, Codable, Hashable, CaseIterable {
    case integerLessThanOrEqual = 1
    case integerGreaterThanOrEqual = 2
    case integerEqual = 3
    case integerNotEqual = 4
    case datetimeLessThanOrEqual = 5
    case datetimeGreaterThanOrEqual = 6
    case booleanEqual = 7
    case booleanNotEqual = 8
}
