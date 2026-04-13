import Foundation

/// Validation helpers for Discord message payloads to ensure compliance with API limits.
/// These helpers provide pre-send validation to prevent API errors from invalid messages.
public enum MessageValidation {
    /// Maximum message content length in characters.
    public static let maxContentLength = 2000
    /// Maximum number of embeds per message.
    public static let maxEmbeds = 10
    /// Maximum number of action rows per message.
    public static let maxActionRows = 5
    /// Maximum number of components per action row.
    public static let maxComponentsPerRow = 25
    /// Maximum file upload size in bytes (25MB default).
    public static let maxFileSizeBytes = 25 * 1024 * 1024
    /// Maximum file upload size in bytes with premium (500MB).
    public static let maxFileSizePremiumBytes = 500 * 1024 * 1024

    /// Errors that can occur during message validation.
    public enum ValidationError: Error, LocalizedDescription {
        case contentTooLong(length: Int, max: Int)
        case tooManyEmbeds(count: Int, max: Int)
        case tooManyActionRows(count: Int, max: Int)
        case tooManyComponentsInRow(count: Int, max: Int)
        case fileTooLarge(size: Int, max: Int)
        case missingRequiredField(field: String)

        public var errorDescription: String? {
            switch self {
            case .contentTooLong(let length, let max):
                return "Message content too long: \(length) characters (max \(max))"
            case .tooManyEmbeds(let count, let max):
                return "Too many embeds: \(count) (max \(max))"
            case .tooManyActionRows(let count, let max):
                return "Too many action rows: \(count) (max \(max))"
            case .tooManyComponentsInRow(let count, let max):
                return "Too many components in action row: \(count) (max \(max))"
            case .fileTooLarge(let size, let max):
                return "File too large: \(size) bytes (max \(max))"
            case .missingRequiredField(let field):
                return "Missing required field: \(field)"
            }
        }
    }

    /// Validate message content length.
    public static func validateContent(_ content: String?) throws {
        guard let content = content, !content.isEmpty else { return }
        let length = content.count
        guard length <= maxContentLength else {
            throw ValidationError.contentTooLong(length: length, max: maxContentLength)
        }
    }

    /// Validate number of embeds.
    public static func validateEmbeds(_ embeds: [Embed]?) throws {
        guard let embeds = embeds, !embeds.isEmpty else { return }
        let count = embeds.count
        guard count <= maxEmbeds else {
            throw ValidationError.tooManyEmbeds(count: count, max: maxEmbeds)
        }
    }

    /// Validate message components structure.
    public static func validateComponents(_ components: [MessageComponent]?) throws {
        guard let components = components, !components.isEmpty else { return }
        let actionRows = components.filter { if case .actionRow = $0 { return true } else { return false } }
        let actionRowCount = actionRows.count
        guard actionRowCount <= maxActionRows else {
            throw ValidationError.tooManyActionRows(count: actionRowCount, max: maxActionRows)
        }

        for component in actionRows {
            if case .actionRow(let row) = component {
                let componentCount = row.components.count
                guard componentCount <= maxComponentsPerRow else {
                    throw ValidationError.tooManyComponentsInRow(count: componentCount, max: maxComponentsPerRow)
                }
            }
        }
    }

    /// Validate file size.
    public static func validateFileSize(_ size: Int, isPremium: Bool = false) throws {
        let maxSize = isPremium ? maxFileSizePremiumBytes : maxFileSizeBytes
        guard size <= maxSize else {
            throw ValidationError.fileTooLarge(size: size, max: maxSize)
        }
    }

    /// Validate a complete message payload.
    public static func validateMessage(
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil
    ) throws {
        try validateContent(content)
        try validateEmbeds(embeds)
        try validateComponents(components)
    }
}

/// Protocol for types that can provide localized error descriptions.
public protocol LocalizedDescription {
    var errorDescription: String? { get }
}
