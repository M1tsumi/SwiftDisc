import Foundation

/// A file to upload as a message attachment.
public struct FileAttachment: Sendable {
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

/// A reference to an existing attachment when editing a message.
public struct PartialAttachment: Encodable, Hashable, Sendable {
    public let id: AttachmentID
    public let description: String?
    /// Whether the attachment is marked as a spoiler.
    /// Added 2026-06-24 per Discord API changelog.
    public let is_spoiler: Bool?

    public init(id: AttachmentID, description: String? = nil, is_spoiler: Bool? = nil) {
        self.id = id
        self.description = description
        self.is_spoiler = is_spoiler
    }
}
