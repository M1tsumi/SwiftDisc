import Foundation

/// Represents a Discord attachment.
///
/// Attachments are files that can be attached to messages, including images,
/// videos, documents, and audio files.
///
/// ## Example
///
/// ```swift
/// if let attachments = message.attachments {
///     for attachment in attachments {
///         print("File: \(attachment.filename)")
///         print("URL: \(attachment.url)")
///         if let size = attachment.size {
///             print("Size: \(size) bytes")
///         }
///     }
/// }
/// ```
public struct Attachment: Codable, Hashable, Sendable {
    /// The attachment ID.
    public let id: AttachmentID
    
    /// The filename of the attachment.
    public let filename: String
    
    /// The size of the attachment in bytes.
    public let size: Int?
    
    /// The source URL of the attachment.
    public let url: String
    
    /// A proxied URL of the attachment.
    public let proxy_url: String?
    
    /// The width of the attachment (for images).
    public let width: Int?
    
    /// The height of the attachment (for images).
    public let height: Int?
    
    /// The content type of the attachment (MIME type).
    public let content_type: String?
    
    /// The description of the attachment (for accessibility).
    public let description: String?
    
    /// Whether the attachment is ephemeral (temporary).
    public let ephemeral: Bool?
    
    // Voice message metadata
    
    /// The duration of the voice message in seconds.
    public let duration_secs: Double?
    
    /// The waveform data for the voice message.
    public let waveform: String?
    
    /// Attachment flags.
    public let flags: Int?
}
