//
//  User.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct User: Codable, Hashable {
    public let id: UserID
    public let username: String
    public let discriminator: String?
    public let globalName: String?
    public let avatar: String?
}
