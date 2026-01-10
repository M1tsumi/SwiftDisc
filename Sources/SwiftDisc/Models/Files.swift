//
//  Files.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct FileAttachment {
    public let filename: String
    public let data: Data
    public let description: String?
    public let contentType: String?

    public init(filename: String, data: Data, description: String? = nil, contentType: String? = nil) {
        self.filename = filename
        self.data = data
        self.description = description
        self.contentType = contentType
    }
}

public struct PartialAttachment: Encodable, Hashable {
    public let id: AttachmentID
    public let description: String?

    public init(id: AttachmentID, description: String? = nil) {
        self.id = id
        self.description = description
    }
}
