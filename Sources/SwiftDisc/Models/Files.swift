import Foundation

public struct FileAttachment {
    public let filename: String
    public let data: Data
    public let description: String?

    public init(filename: String, data: Data, description: String? = nil) {
        self.filename = filename
        self.data = data
        self.description = description
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
