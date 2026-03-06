import Foundation

public struct Attachment: Codable, Hashable, Sendable {
    public let id: AttachmentID
    public let filename: String
    public let size: Int?
    public let url: String
    public let proxy_url: String?
    public let width: Int?
    public let height: Int?
    public let content_type: String?
    public let description: String?
    public let ephemeral: Bool?
    // Voice message metadata
    public let duration_secs: Double?
    public let waveform: String?
}
