import Foundation

public enum MessageComponent: Codable, Hashable, Sendable {
    case actionRow(ActionRow)
    case button(Button)
    case select(SelectMenu)
    case userSelect(UserSelectMenu)
    case roleSelect(RoleSelectMenu)
    case mentionableSelect(MentionableSelectMenu)
    case channelSelect(ChannelSelectMenu)
    case textInput(TextInput)
    /// Label layout component for modals (type 21). Introduced 2026-02-12 alongside new modal components.
    case label(Label)
    /// Radio Group for single-selection inside a modal Label (type 22). Introduced 2026-02-12.
    case radioGroup(RadioGroup)
    /// Checkbox Group for multi-selection inside a modal Label (type 23). Introduced 2026-02-12.
    case checkboxGroup(CheckboxGroup)
    /// Checkbox boolean toggle inside a modal Label (type 24). Introduced 2026-02-12.
    case checkbox(Checkbox)
    /// File Upload component for modals (type 25). Allows users to upload files through modal submissions. Introduced 2026.
    case fileUpload(FileUpload)

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(Int.self, forKey: .type)
        switch type {
        case 1: self = .actionRow(try ActionRow(from: decoder))
        case 2: self = .button(try Button(from: decoder))
        case 3: self = .select(try SelectMenu(from: decoder))
        case 5: self = .userSelect(try UserSelectMenu(from: decoder))
        case 6: self = .roleSelect(try RoleSelectMenu(from: decoder))
        case 7: self = .mentionableSelect(try MentionableSelectMenu(from: decoder))
        case 8: self = .channelSelect(try ChannelSelectMenu(from: decoder))
        case 4: self = .textInput(try TextInput(from: decoder))
        case 21: self = .label(try Label(from: decoder))
        case 22: self = .radioGroup(try RadioGroup(from: decoder))
        case 23: self = .checkboxGroup(try CheckboxGroup(from: decoder))
        case 24: self = .checkbox(try Checkbox(from: decoder))
        case 25: self = .fileUpload(try FileUpload(from: decoder))
        default:
            // Unknown component types are treated as buttons to keep decoding resilient.
            self = .button(try Button(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .actionRow(let row): try row.encode(to: encoder)
        case .button(let btn): try btn.encode(to: encoder)
        case .select(let sel): try sel.encode(to: encoder)
        case .userSelect(let us): try us.encode(to: encoder)
        case .roleSelect(let rs): try rs.encode(to: encoder)
        case .mentionableSelect(let ms): try ms.encode(to: encoder)
        case .channelSelect(let cs): try cs.encode(to: encoder)
        case .textInput(let ti): try ti.encode(to: encoder)
        case .label(let l): try l.encode(to: encoder)
        case .radioGroup(let rg): try rg.encode(to: encoder)
        case .checkboxGroup(let cg): try cg.encode(to: encoder)
        case .checkbox(let cb): try cb.encode(to: encoder)
        case .fileUpload(let fu): try fu.encode(to: encoder)
        }
    }

    private enum CodingKeys: String, CodingKey { case type }

    public struct ActionRow: Codable, Hashable, Sendable {
        public let type: Int
        public let components: [MessageComponent]
        public init(components: [MessageComponent]) {
            self.type = 1
            self.components = components
        }
    }

    public struct Button: Codable, Hashable, Sendable {
        public let type: Int
        public let style: Int
        public let label: String?
        public let custom_id: String?
        public let url: String?
        public let disabled: Bool?
        /// SKU ID for premium button style (style 10). Required when using PREMIUM_REQUIRED button style.
        /// Introduced for Discord Premium Apps monetization.
        public let sku_id: SKUID?
        public init(style: Int, label: String? = nil, custom_id: String? = nil, url: String? = nil, disabled: Bool? = nil, sku_id: SKUID? = nil) {
            self.type = 2
            self.style = style
            self.label = label
            self.custom_id = custom_id
            self.url = url
            self.disabled = disabled
            self.sku_id = sku_id
        }
    }

    public struct SelectMenu: Codable, Hashable, Sendable {
        public struct Option: Codable, Hashable, Sendable {
            public let label: String
            public let value: String
            public let description: String?
            public let emoji: String?
            public let `default`: Bool?
        }
        public let type: Int
        public let custom_id: String
        public let options: [Option]
        public let placeholder: String?
        public let min_values: Int?
        public let max_values: Int?
        public let disabled: Bool?
        public init(custom_id: String, options: [Option], placeholder: String? = nil, min_values: Int? = nil, max_values: Int? = nil, disabled: Bool? = nil) {
            self.type = 3
            self.custom_id = custom_id
            self.options = options
            self.placeholder = placeholder
            self.min_values = min_values
            self.max_values = max_values
            self.disabled = disabled
        }
    }

    public struct UserSelectMenu: Codable, Hashable, Sendable {
        public let type: Int
        public let custom_id: String
        public let placeholder: String?
        public let min_values: Int?
        public let max_values: Int?
        public let disabled: Bool?
        public let default_values: [DefaultSelectValue]?
        public init(custom_id: String, placeholder: String? = nil, min_values: Int? = nil, max_values: Int? = nil, disabled: Bool? = nil, default_values: [DefaultSelectValue]? = nil) {
            self.type = 5
            self.custom_id = custom_id
            self.placeholder = placeholder
            self.min_values = min_values
            self.max_values = max_values
            self.disabled = disabled
            self.default_values = default_values
        }
    }

    public struct RoleSelectMenu: Codable, Hashable, Sendable {
        public let type: Int
        public let custom_id: String
        public let placeholder: String?
        public let min_values: Int?
        public let max_values: Int?
        public let disabled: Bool?
        public let default_values: [DefaultSelectValue]?
        public init(custom_id: String, placeholder: String? = nil, min_values: Int? = nil, max_values: Int? = nil, disabled: Bool? = nil, default_values: [DefaultSelectValue]? = nil) {
            self.type = 6
            self.custom_id = custom_id
            self.placeholder = placeholder
            self.min_values = min_values
            self.max_values = max_values
            self.disabled = disabled
            self.default_values = default_values
        }
    }

    public struct MentionableSelectMenu: Codable, Hashable, Sendable {
        public let type: Int
        public let custom_id: String
        public let placeholder: String?
        public let min_values: Int?
        public let max_values: Int?
        public let disabled: Bool?
        public let default_values: [DefaultSelectValue]?
        public init(custom_id: String, placeholder: String? = nil, min_values: Int? = nil, max_values: Int? = nil, disabled: Bool? = nil, default_values: [DefaultSelectValue]? = nil) {
            self.type = 7
            self.custom_id = custom_id
            self.placeholder = placeholder
            self.min_values = min_values
            self.max_values = max_values
            self.disabled = disabled
            self.default_values = default_values
        }
    }

    public struct ChannelSelectMenu: Codable, Hashable, Sendable {
        public let type: Int
        public let custom_id: String
        public let placeholder: String?
        public let min_values: Int?
        public let max_values: Int?
        public let disabled: Bool?
        public let channel_types: [Int]?
        public let default_values: [DefaultSelectValue]?
        public init(custom_id: String, placeholder: String? = nil, min_values: Int? = nil, max_values: Int? = nil, disabled: Bool? = nil, channel_types: [Int]? = nil, default_values: [DefaultSelectValue]? = nil) {
            self.type = 8
            self.custom_id = custom_id
            self.placeholder = placeholder
            self.min_values = min_values
            self.max_values = max_values
            self.disabled = disabled
            self.channel_types = channel_types
            self.default_values = default_values
        }
    }

    public struct DefaultSelectValue: Codable, Hashable, Sendable {
        public let id: String
        public let type: DefaultSelectValueType
        public init(id: String, type: DefaultSelectValueType) {
            self.id = id
            self.type = type
        }
    }

    public enum DefaultSelectValueType: String, Codable, Hashable, Sendable {
        case user
        case role
        case channel
        case mentionable
    }

    public struct TextInput: Codable, Hashable, Sendable {
        public enum Style: Int, Codable, Sendable { case short = 1, paragraph = 2 }
        public let type: Int
        public let custom_id: String
        public let style: Style
        public let label: String
        public let min_length: Int?
        public let max_length: Int?
        public let required: Bool?
        public let value: String?
        public let placeholder: String?
        public init(custom_id: String, style: Style, label: String, min_length: Int? = nil, max_length: Int? = nil, required: Bool? = nil, value: String? = nil, placeholder: String? = nil) {
            self.type = 4
            self.custom_id = custom_id
            self.style = style
            self.label = label
            self.min_length = min_length
            self.max_length = max_length
            self.required = required
            self.value = value
            self.placeholder = placeholder
        }
    }

    // MARK: - New Modal Components (added 2026-02-12)

    /// Label layout component (type 21). Top-level container for modal components.
    /// Provides a `label` and optional `description`, and wraps a single interactive component.
    public struct Label: Codable, Hashable, Sendable {
        public let type: Int
        public let label: String
        public let description: String?
        /// The single-child component (TextInput, StringSelect, RadioGroup, CheckboxGroup, or Checkbox).
        public let components: [MessageComponent]?
        public init(label: String, description: String? = nil, components: [MessageComponent]? = nil) {
            self.type = 21
            self.label = label
            self.description = description
            self.components = components
        }
    }

    /// Radio Group component (type 22). Single-selection picker for modals; must be inside a Label.
    public struct RadioGroup: Codable, Hashable, Sendable {
        public let type: Int
        public let custom_id: String
        public let options: [RadioOption]
        public let required: Bool?
        public struct RadioOption: Codable, Hashable, Sendable {
            public let label: String
            public let value: String
            public let description: String?
            public let `default`: Bool?
            public init(label: String, value: String, description: String? = nil, isDefault: Bool? = nil) {
                self.label = label
                self.value = value
                self.description = description
                self.default = isDefault
            }
        }
        public init(custom_id: String, options: [RadioOption], required: Bool? = nil) {
            self.type = 22
            self.custom_id = custom_id
            self.options = options
            self.required = required
        }
    }

    /// Checkbox Group component (type 23). Multi-selection picker for modals; must be inside a Label.
    public struct CheckboxGroup: Codable, Hashable, Sendable {
        public let type: Int
        public let custom_id: String
        public let options: [CheckboxOption]
        public let min_values: Int?
        public let max_values: Int?
        public struct CheckboxOption: Codable, Hashable, Sendable {
            public let label: String
            public let value: String
            public let description: String?
            public let `default`: Bool?
            public init(label: String, value: String, description: String? = nil, isDefault: Bool? = nil) {
                self.label = label
                self.value = value
                self.description = description
                self.default = isDefault
            }
        }
        public init(custom_id: String, options: [CheckboxOption], minValues: Int? = nil, maxValues: Int? = nil) {
            self.type = 23
            self.custom_id = custom_id
            self.options = options
            self.min_values = minValues
            self.max_values = maxValues
        }
    }

    /// Checkbox component (type 24). Boolean yes/no toggle for modals; must be inside a Label.
    public struct Checkbox: Codable, Hashable, Sendable {
        public let type: Int
        public let custom_id: String
        public let required: Bool?
        public let `default`: Bool?
        public init(custom_id: String, required: Bool? = nil, isDefault: Bool? = nil) {
            self.type = 24
            self.custom_id = custom_id
            self.required = required
            self.default = isDefault
        }
    }

    /// File Upload component (type 25). Allows users to upload files through modal submissions.
    /// Must be inside a Label container. Introduced 2026.
    public struct FileUpload: Codable, Hashable, Sendable {
        public let type: Int
        public let custom_id: String
        public let label: String
        public let min_length: Int?
        public let max_length: Int?
        public let required: Bool?
        public let placeholder: String?
        public init(custom_id: String, label: String, min_length: Int? = nil, max_length: Int? = nil, required: Bool? = nil, placeholder: String? = nil) {
            self.type = 25
            self.custom_id = custom_id
            self.label = label
            self.min_length = min_length
            self.max_length = max_length
            self.required = required
            self.placeholder = placeholder
        }
    }
}
