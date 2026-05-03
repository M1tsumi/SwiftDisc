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
    
    /// Maximum number of poll answers.
    public static let maxPollAnswers = 10
    
    /// Maximum poll answer text length.
    public static let maxPollAnswerLength = 55
    
    /// Maximum poll question length.
    public static let maxPollQuestionLength = 300

    /// Errors that can occur during message validation.
    public enum ValidationError: Error, LocalizedDescription {
        case contentTooLong(length: Int, max: Int)
        case tooManyEmbeds(count: Int, max: Int)
        case tooManyActionRows(count: Int, max: Int)
        case tooManyComponentsInRow(count: Int, max: Int)
        case fileTooLarge(size: Int, max: Int)
        case missingRequiredField(field: String)
        case tooManyPollAnswers(count: Int, max: Int)
        case pollAnswerTooLong(length: Int, max: Int)
        case pollQuestionTooLong(length: Int, max: Int)
        case embedFieldTooLong(field: String, length: Int, max: Int)
        case embedTitleTooLong(length: Int, max: Int)
        case embedDescriptionTooLong(length: Int, max: Int)
        case tooManyEmbedFields(count: Int, max: Int)

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
            case .tooManyPollAnswers(let count, let max):
                return "Too many poll answers: \(count) (max \(max))"
            case .pollAnswerTooLong(let length, let max):
                return "Poll answer too long: \(length) characters (max \(max))"
            case .pollQuestionTooLong(let length, let max):
                return "Poll question too long: \(length) characters (max \(max))"
            case .embedFieldTooLong(let field, let length, let max):
                return "Embed field '\(field)' too long: \(length) characters (max \(max))"
            case .embedTitleTooLong(let length, let max):
                return "Embed title too long: \(length) characters (max \(max))"
            case .embedDescriptionTooLong(let length, let max):
                return "Embed description too long: \(length) characters (max \(max))"
            case .tooManyEmbedFields(let count, let max):
                return "Too many embed fields: \(count) (max \(max))"
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
    
    /// Validate embed fields.
    public static func validateEmbedFields(_ fields: [Embed.Field]?) throws {
        guard let fields = fields, !fields.isEmpty else { return }
        let count = fields.count
        guard count <= 25 else {
            throw ValidationError.tooManyEmbedFields(count: count, max: 25)
        }
        for field in fields {
            let nameLength = field.name.count
            guard nameLength <= 256 else {
                throw ValidationError.embedFieldTooLong(field: "name", length: nameLength, max: 256)
            }
            let valueLength = field.value.count
            guard valueLength <= 1024 else {
                throw ValidationError.embedFieldTooLong(field: "value", length: valueLength, max: 1024)
            }
        }
    }
    
    /// Validate embed title and description.
    public static func validateEmbedLimits(_ embed: Embed) throws {
        if let title = embed.title {
            let length = title.count
            guard length <= 256 else {
                throw ValidationError.embedTitleTooLong(length: length, max: 256)
            }
        }
        if let description = embed.description {
            let length = description.count
            guard length <= 4096 else {
                throw ValidationError.embedDescriptionTooLong(length: length, max: 4096)
            }
        }
        try validateEmbedFields(embed.fields)
    }
    
    /// Validate poll question.
    public static func validatePollQuestion(_ question: String) throws {
        let length = question.count
        guard length <= maxPollQuestionLength else {
            throw ValidationError.pollQuestionTooLong(length: length, max: maxPollQuestionLength)
        }
    }
    
    /// Validate poll answers.
    public static func validatePollAnswers(_ answers: [String]) throws {
        let count = answers.count
        guard count >= 2 else {
            throw ValidationError.missingRequiredField(field: "Poll must have at least 2 answers")
        }
        guard count <= maxPollAnswers else {
            throw ValidationError.tooManyPollAnswers(count: count, max: maxPollAnswers)
        }
        for answer in answers {
            let length = answer.count
            guard length <= maxPollAnswerLength else {
                throw ValidationError.pollAnswerTooLong(length: length, max: maxPollAnswerLength)
            }
        }
    }
}

/// Protocol for types that can provide localized error descriptions.
public protocol LocalizedDescription {
    var errorDescription: String? { get }
}
