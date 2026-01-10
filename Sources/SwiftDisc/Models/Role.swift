//
//  Role.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Role: Codable, Hashable {
    public let id: RoleID
    public let name: String
    public let color: Int?
    public let hoist: Bool?
    public let position: Int?
    public let permissions: String?
    public let managed: Bool?
    public let mentionable: Bool?
}
