//
//  Attachment.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Attachment: Codable, Hashable {
    public let id: AttachmentID
    public let filename: String
    public let size: Int?
    public let url: String
    public let proxy_url: String?
    public let width: Int?
    public let height: Int?
}
