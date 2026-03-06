import Foundation

public enum MessageComponent: Codable, Hashable, Sendable {
    case actionRow(ActionRow)
    case button(Button)
    case select(SelectMenu)
    case textInput(TextInput)
    /// Label layout component for modals (type 21). Introduced 2026-02-12 alongside new modal components.
    case label(Label)
    /// Radio Group for single-selection inside a modal Label (type 22). Introduced 2026-02-12.
    case radioGroup(RadioGroup)
    /// Checkbox Group for multi-selection inside a modal Label (type 23). Introduced 2026-02-12.
    case checkboxGroup(CheckboxGroup)
    /// Checkbox boolean toggle inside a modal Label (type 24). Introduced 2026-02-12.
    case checkbox(Checkbox)

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(Int.self, forKey: .type)
        switch type {
        case 1: self = .actionRow(try ActionRow(from: decoder))
        case 2: self = .button(try Button(from: decoder))
        case 3: self = .select(try SelectMenu(from: decoder))
        case 4: self = .textInput(try TextInput(from: decoder))
        case 21: self = .label(try Label(from: decoder))
        case 22: self = .radioGroup(try RadioGroup(from: decoder))
        case 23: self = .checkboxGroup(try CheckboxGroup(from: decoder))
        case 24: self = .checkbox(try Checkbox(from: decoder))
        default:
            // Fallback: attempt button
            self = .button(try Button(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .actionRow(let row): try row.encode(to: encoder)
        case .button(let btn): try btn.encode(to: encoder)
        case .select(let sel): try sel.encode(to: encoder)
        case .textInput(let ti): try ti.encode(to: encoder)
        case .label(let l): try l.encode(to: encoder)
        case .radioGroup(let rg): try rg.encode(to: encoder)
        case .checkboxGroup(let cg): try cg.encode(to: encoder)
        case .checkbox(let cb): try cb.encode(to: encoder)
        }
    }

    private enum CodingKeys: String, CodingKey { case type }

    public struct ActionRow: Codable, Hashable, Sendable {
        public let type: Int = 1
        public let components: [MessageComponent]
        public init(components: [MessageComponent]) { self.components = components }
    }

    public struct Button: Codable, Hashable, Sendable {
        public let type: Int = 2
        public let style: Int
        public let label: String?
        public let custom_id: String?
        public let url: String?
        public let disabled: Bool?
        public init(style: Int, label: String? = nil, custom_id: String? = nil, url: String? = nil, disabled: Bool? = nil) {
            self.style = style
            self.label = label
            self.custom_id = custom_id
            self.url = url
            self.disabled = disabled
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
        public let type: Int = 3
        public let custom_id: String
        public let options: [Option]
        public let placeholder: String?
        public let min_values: Int?
        public let max_values: Int?
        public let disabled: Bool?
        public init(custom_id: String, options: [Option], placeholder: String? = nil, min_values: Int? = nil, max_values: Int? = nil, disabled: Bool? = nil) {
            self.custom_id = custom_id
            self.options = options
            self.placeholder = placeholder
            self.min_values = min_values
            self.max_values = max_values
            self.disabled = disabled
        }
    }

    public struct TextInput: Codable, Hashable, Sendable {
        public enum Style: Int, Codable, Sendable { case short = 1, paragraph = 2 }
        public let type: Int = 4
        public let custom_id: String
        public let style: Style
        public let label: String
        public let min_length: Int?
        public let max_length: Int?
        public let required: Bool?
        public let value: String?
        public let placeholder: String?
        public init(custom_id: String, style: Style, label: String, min_length: Int? = nil, max_length: Int? = nil, required: Bool? = nil, value: String? = nil, placeholder: String? = nil) {
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
        public let type: Int = 21
        public let label: String
        public let description: String?
        /// The single-child component (TextInput, StringSelect, RadioGroup, CheckboxGroup, or Checkbox).
        public let components: [MessageComponent]?
        public init(label: String, description: String? = nil, components: [MessageComponent]? = nil) {
            self.label = label
            self.description = description
            self.components = components
        }
    }

    /// Radio Group component (type 22). Single-selection picker for modals; must be inside a Label.
    public struct RadioGroup: Codable, Hashable, Sendable {
        public let type: Int = 22
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
            self.custom_id = custom_id
            self.options = options
            self.required = required
        }
    }

    /// Checkbox Group component (type 23). Multi-selection picker for modals; must be inside a Label.
    public struct CheckboxGroup: Codable, Hashable, Sendable {
        public let type: Int = 23
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
            self.custom_id = custom_id
            self.options = options
            self.min_values = minValues
            self.max_values = maxValues
        }
    }

    /// Checkbox component (type 24). Boolean yes/no toggle for modals; must be inside a Label.
    public struct Checkbox: Codable, Hashable, Sendable {
        public let type: Int = 24
        public let custom_id: String
        public let required: Bool?
        public let `default`: Bool?
        public init(custom_id: String, required: Bool? = nil, isDefault: Bool? = nil) {
            self.custom_id = custom_id
            self.required = required
            self.default = isDefault
        }
    }
}
