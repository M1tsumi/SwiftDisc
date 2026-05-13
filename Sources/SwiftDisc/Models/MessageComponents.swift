import Foundation

/// Represents a Discord message component.
///
/// Components are interactive UI elements that can be attached to messages and modals.
/// They include buttons, select menus, text inputs, and more.
///
/// ## Component Types
/// - `1`: Action Row (container for other components)
/// - `2`: Button
/// - `3`: Select Menu (text)
/// - `4`: Text Input (for modals)
/// - `5`: User Select Menu
/// - `6`: Role Select Menu
/// - `7`: Mentionable Select Menu
/// - `8`: Channel Select Menu
/// - `21`: Label (modal layout component)
/// - `22`: Radio Group (modal)
/// - `23`: Checkbox Group (modal)
/// - `24`: Checkbox (modal)
/// - `25`: File Upload (modal)
///
/// ## Example
///
/// ```swift
/// let button = MessageComponent.Button(style: 1, label: "Click Me", custom_id: "btn_click")
/// let row = MessageComponent.ActionRow(components: [button])
/// try await client.sendMessage(channelId: channelId, components: [row])
/// ```
///
/// ## See Also
/// - `ComponentsBuilder`
/// - `ButtonBuilder`
/// - `SelectMenuBuilder`
public enum MessageComponent: Codable, Hashable, Sendable {
    /// An action row container for other components.
    case actionRow(ActionRow)
    
    /// A button component.
    case button(Button)
    
    /// A text select menu component.
    case select(SelectMenu)
    
    /// A user select menu component.
    case userSelect(UserSelectMenu)
    
    /// A role select menu component.
    case roleSelect(RoleSelectMenu)
    
    /// A mentionable select menu component (users and roles).
    case mentionableSelect(MentionableSelectMenu)
    
    /// A channel select menu component.
    case channelSelect(ChannelSelectMenu)
    
    /// A text input component (for modals).
    case textInput(TextInput)
    
    /// A label layout component for modals (type 21, introduced 2026-02-12).
    case label(Label)
    
    /// A radio group for single-selection inside a modal label (type 22, introduced 2026-02-12).
    case radioGroup(RadioGroup)
    
    /// A checkbox group for multi-selection inside a modal label (type 23, introduced 2026-02-12).
    case checkboxGroup(CheckboxGroup)
    
    /// A checkbox boolean toggle inside a modal label (type 24, introduced 2026-02-12).
    case checkbox(Checkbox)
    
    /// A file upload component for modals (type 25, introduced 2026).
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

    /// Represents an action row component.
    ///
    /// Action rows are containers that hold other components (buttons, select menus, etc.).
    /// You can have up to 5 action rows per message, and each row can hold up to 5 buttons or 1 select menu.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let button1 = MessageComponent.Button(style: 1, label: "Yes", custom_id: "btn_yes")
    /// let button2 = MessageComponent.Button(style: 2, label: "No", custom_id: "btn_no")
    /// let row = MessageComponent.ActionRow(components: [button1, button2])
    /// ```
    public struct ActionRow: Codable, Hashable, Sendable {
        /// The component type (always 1 for action rows).
        public let type: Int
        
        /// The components in this action row.
        public let components: [MessageComponent]
        
        public init(components: [MessageComponent]) {
            self.type = 1
            self.components = components
        }
    }

    /// Represents a button component.
    ///
    /// Buttons are interactive components that users can click to trigger interactions.
    ///
    /// ## Button Styles
    /// - `1`: Primary (blurple)
    /// - `2`: Secondary (grey)
    /// - `3`: Success (green)
    /// - `4`: Danger (red)
    /// - `5`: Link (requires `url` instead of `custom_id`)
    /// - `10`: Premium Required (requires `sku_id`)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Interactive button
    /// let button = MessageComponent.Button(
    ///     style: 1,
    ///     label: "Click Me",
    ///     custom_id: "btn_click"
    /// )
    ///
    /// // Link button
    /// let link = MessageComponent.Button(
    ///     style: 5,
    ///     label: "Visit Discord",
    ///     url: "https://discord.com"
    /// )
    /// ```
    public struct Button: Codable, Hashable, Sendable {
        /// The component type (always 2 for buttons).
        public let type: Int
        
        /// The button style (1-5, 10).
        public let style: Int
        
        /// The label text displayed on the button.
        public let label: String?
        
        /// The custom ID for identifying this button (required for interactive buttons).
        public let custom_id: String?
        
        /// The URL to open when the button is clicked (required for link buttons).
        public let url: String?
        
        /// Whether the button is disabled.
        public let disabled: Bool?
        
        /// The SKU ID for premium button style (required for style 10).
        ///
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

    /// Represents a text select menu component.
    ///
    /// Select menus allow users to choose from a list of predefined options.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let option1 = MessageComponent.SelectMenu.Option(label: "Option 1", value: "opt1")
    /// let option2 = MessageComponent.SelectMenu.Option(label: "Option 2", value: "opt2")
    /// let select = MessageComponent.SelectMenu(
    ///     custom_id: "select_menu",
    ///     options: [option1, option2]
    /// )
    /// ```
    public struct SelectMenu: Codable, Hashable, Sendable {
        /// Represents an option in a select menu.
        public struct Option: Codable, Hashable, Sendable {
            /// The label displayed to the user.
            public let label: String
            
            /// The internal value returned when selected.
            public let value: String
            
            /// An optional description of the option.
            public let description: String?
            
            /// The emoji for this option.
            public let emoji: String?
            
            /// Whether this option is selected by default.
            public let `default`: Bool?
        }
        
        /// The component type (always 3 for select menus).
        public let type: Int
        
        /// The custom ID for identifying this select menu.
        public let custom_id: String
        
        /// The options available in this select menu.
        public let options: [Option]
        
        /// The placeholder text displayed when no option is selected.
        public let placeholder: String?
        
        /// The minimum number of items that must be selected (0-25, default 1).
        public let min_values: Int?
        
        /// The maximum number of items that can be selected (0-25, default 1).
        public let max_values: Int?
        
        /// Whether the select menu is disabled.
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

    /// Represents a user select menu component.
    ///
    /// User select menus allow users to select from a list of users in the server.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let select = MessageComponent.UserSelectMenu(
    ///     custom_id: "user_select",
    ///     placeholder: "Select a user"
    /// )
    /// ```
    public struct UserSelectMenu: Codable, Hashable, Sendable {
        /// The component type (always 5 for user select menus).
        public let type: Int
        
        /// The custom ID for identifying this select menu.
        public let custom_id: String
        
        /// The placeholder text displayed when no option is selected.
        public let placeholder: String?
        
        /// The minimum number of items that must be selected (0-25, default 1).
        public let min_values: Int?
        
        /// The maximum number of items that can be selected (0-25, default 1).
        public let max_values: Int?
        
        /// Whether the select menu is disabled.
        public let disabled: Bool?
        
        /// The default selected values.
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

    /// Represents a role select menu component.
    ///
    /// Role select menus allow users to select from a list of roles in the server.
    public struct RoleSelectMenu: Codable, Hashable, Sendable {
        /// The component type (always 6 for role select menus).
        public let type: Int
        
        /// The custom ID for identifying this select menu.
        public let custom_id: String
        
        /// The placeholder text displayed when no option is selected.
        public let placeholder: String?
        
        /// The minimum number of items that must be selected (0-25, default 1).
        public let min_values: Int?
        
        /// The maximum number of items that can be selected (0-25, default 1).
        public let max_values: Int?
        
        /// Whether the select menu is disabled.
        public let disabled: Bool?
        
        /// The default selected values.
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

    /// Represents a mentionable select menu component.
    ///
    /// Mentionable select menus allow users to select from users and roles.
    public struct MentionableSelectMenu: Codable, Hashable, Sendable {
        /// The component type (always 7 for mentionable select menus).
        public let type: Int
        
        /// The custom ID for identifying this select menu.
        public let custom_id: String
        
        /// The placeholder text displayed when no option is selected.
        public let placeholder: String?
        
        /// The minimum number of items that must be selected (0-25, default 1).
        public let min_values: Int?
        
        /// The maximum number of items that can be selected (0-25, default 1).
        public let max_values: Int?
        
        /// Whether the select menu is disabled.
        public let disabled: Bool?
        
        /// The default selected values.
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

    /// Represents a channel select menu component.
    ///
    /// Channel select menus allow users to select from a list of channels in the server.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let select = MessageComponent.ChannelSelectMenu(
    ///     custom_id: "channel_select",
    ///     placeholder: "Select a channel"
    /// )
    /// ```
    public struct ChannelSelectMenu: Codable, Hashable, Sendable {
        /// The component type (always 8 for channel select menus).
        public let type: Int
        
        /// The custom ID for identifying this select menu.
        public let custom_id: String
        
        /// The placeholder text displayed when no option is selected.
        public let placeholder: String?
        
        /// The minimum number of items that must be selected (0-25, default 1).
        public let min_values: Int?
        
        /// The maximum number of items that can be selected (0-25, default 1).
        public let max_values: Int?
        
        /// Whether the select menu is disabled.
        public let disabled: Bool?
        
        /// The default selected values.
        public let default_values: [DefaultSelectValue]?
        
        /// The channel types to include in the select menu.
        public let channel_types: [Int]?
        
        public init(custom_id: String, placeholder: String? = nil, min_values: Int? = nil, max_values: Int? = nil, disabled: Bool? = nil, default_values: [DefaultSelectValue]? = nil, channel_types: [Int]? = nil) {
            self.type = 8
            self.custom_id = custom_id
            self.placeholder = placeholder
            self.min_values = min_values
            self.max_values = max_values
            self.disabled = disabled
            self.default_values = default_values
            self.channel_types = channel_types
        }
    }

    /// Represents a text input component (for modals).
    ///
    /// Text inputs allow users to enter text in modals.
    ///
    /// ## Text Input Styles
    /// - `1`: Short (single line)
    /// - `2`: Paragraph (multi-line)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let input = MessageComponent.TextInput(
    ///     custom_id: "text_input",
    ///     style: 1,
    ///     label: "Enter your name",
    ///     placeholder: "John Doe"
    /// )
    /// ```
    public struct TextInput: Codable, Hashable, Sendable {
        /// The component type (always 4 for text inputs).
        public let type: Int
        
        /// The custom ID for identifying this text input.
        public let custom_id: String
        
        /// The text input style (1-2).
        public let style: Int
        
        /// The label displayed above the text input.
        public let label: String
        
        /// The minimum length of the text input (0-4000, default 0).
        public let min_length: Int?
        
        /// The maximum length of the text input (1-4000, default 4000).
        public let max_length: Int?
        
        /// Whether this text input is required.
        public let required: Bool?
        
        /// The pre-filled value of the text input.
        public let value: String?
        
        /// The placeholder text displayed when the input is empty.
        public let placeholder: String?
        
        public init(custom_id: String, style: Int, label: String, min_length: Int? = nil, max_length: Int? = nil, required: Bool? = nil, value: String? = nil, placeholder: String? = nil) {
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
