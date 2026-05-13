import Foundation

/// A builder for creating Discord button components.
///
/// Use this builder to construct buttons with various styles and behaviors.
///
/// ## Example
///
/// ```swift
/// let button = ButtonBuilder()
///     .style(.primary)
///     .label("Click Me")
///     .customId("btn_click")
///     .build()
/// ```
public struct ButtonBuilder: Sendable {
    /// Button styles.
    public enum Style: Int, Sendable {
        /// Primary (blurple).
        case primary = 1
        
        /// Secondary (grey).
        case secondary = 2
        
        /// Success (green).
        case success = 3
        
        /// Danger (red).
        case danger = 4
        
        /// Link (requires URL).
        case link = 5
        
        /// Premium button style (style 10). Requires sku_id for premium subscription gating.
        /// Introduced for Discord Premium Apps monetization.
        case premium = 10
    }
    
    private var style: Int = Style.primary.rawValue
    private var label: String?
    private var customId: String?
    private var url: String?
    private var skuId: SKUID?
    private var disabled: Bool?
    
    /// Creates a new button builder.
    public init() {}
    
    /// Sets the button style.
    public func style(_ s: Style) -> ButtonBuilder { var c = self; c.style = s.rawValue; return c }
    
    /// Sets the button label.
    public func label(_ t: String) -> ButtonBuilder { var c = self; c.label = t; return c }
    
    /// Sets the button custom ID (required for interactive buttons).
    public func customId(_ id: String) -> ButtonBuilder { var c = self; c.customId = id; return c }
    
    /// Sets the button URL (required for link buttons).
    public func url(_ u: String) -> ButtonBuilder { var c = self; c.url = u; return c }
    
    /// Sets the SKU ID (required for premium buttons).
    public func skuId(_ id: SKUID) -> ButtonBuilder { var c = self; c.skuId = id; return c }
    
    /// Sets whether the button is disabled.
    public func disabled(_ d: Bool = true) -> ButtonBuilder { var c = self; c.disabled = d; return c }
    
    /// Builds the button.
    public func build() -> MessageComponent {
        MessageComponent.button(.init(style: style, label: label, custom_id: customId, url: url, disabled: disabled, sku_id: skuId))
    }
}

/// A builder for creating text select menu components.
///
/// Use this builder to construct select menus with predefined options.
///
/// ## Example
///
/// ```swift
/// let select = SelectMenuBuilder()
///     .customId("select_menu")
///     .option(label: "Option 1", value: "opt1")
///     .option(label: "Option 2", value: "opt2")
///     .build()
/// ```
public struct SelectMenuBuilder: Sendable {
    private var customId: String = ""
    private var options: [MessageComponent.SelectMenu.Option] = []
    private var placeholder: String?
    private var min: Int?
    private var max: Int?
    private var disabled: Bool?
    
    /// Creates a new select menu builder.
    public init() {}
    
    /// Sets the custom ID.
    public func customId(_ id: String) -> SelectMenuBuilder { var c = self; c.customId = id; return c }
    
    /// Adds an option to the select menu.
    public func option(label: String, value: String, description: String? = nil, emoji: String? = nil, isDefault: Bool? = nil) -> SelectMenuBuilder {
        var c = self
        c.options.append(.init(label: label, value: value, description: description, emoji: emoji, default: isDefault))
        return c
    }
    
    /// Sets the placeholder text.
    public func placeholder(_ t: String) -> SelectMenuBuilder { var c = self; c.placeholder = t; return c }
    
    /// Sets the minimum number of selectable values.
    public func minValues(_ v: Int) -> SelectMenuBuilder { var c = self; c.min = v; return c }
    
    /// Sets the maximum number of selectable values.
    public func maxValues(_ v: Int) -> SelectMenuBuilder { var c = self; c.max = v; return c }
    
    /// Sets whether the select menu is disabled.
    public func disabled(_ d: Bool = true) -> SelectMenuBuilder { var c = self; c.disabled = d; return c }
    
    /// Builds the select menu.
    public func build() -> MessageComponent {
        MessageComponent.select(.init(custom_id: customId, options: options, placeholder: placeholder, min_values: min, max_values: max, disabled: disabled))
    }
}

// MARK: - String Select Menu Builder (Discord's newer select menu type)

public struct StringSelectMenuBuilder: Sendable {
    private var customId: String = ""
    private var options: [MessageComponent.SelectMenu.Option] = []
    private var placeholder: String?
    private var min: Int?
    private var max: Int?
    private var disabled: Bool?
    public init() {}
    public func customId(_ id: String) -> StringSelectMenuBuilder { var c = self; c.customId = id; return c }
    public func option(label: String, value: String, description: String? = nil, emoji: String? = nil, isDefault: Bool? = nil) -> StringSelectMenuBuilder {
        var c = self
        c.options.append(.init(label: label, value: value, description: description, emoji: emoji, default: isDefault))
        return c
    }
    public func placeholder(_ t: String) -> StringSelectMenuBuilder { var c = self; c.placeholder = t; return c }
    public func minValues(_ v: Int) -> StringSelectMenuBuilder { var c = self; c.min = v; return c }
    public func maxValues(_ v: Int) -> StringSelectMenuBuilder { var c = self; c.max = v; return c }
    public func disabled(_ d: Bool = true) -> StringSelectMenuBuilder { var c = self; c.disabled = d; return c }
    public func build() -> MessageComponent {
        MessageComponent.select(.init(custom_id: customId, options: options, placeholder: placeholder, min_values: min, max_values: max, disabled: disabled))
    }
}

// MARK: - Channel Select Menu Builder

public struct ChannelSelectMenuBuilder: Sendable {
    private var customId: String = ""
    private var placeholder: String?
    private var channelTypes: [Int]?
    private var defaultChannelIds: [ChannelID]?
    private var disabled: Bool?
    public init() {}
    public func customId(_ id: String) -> ChannelSelectMenuBuilder { var c = self; c.customId = id; return c }
    public func placeholder(_ t: String) -> ChannelSelectMenuBuilder { var c = self; c.placeholder = t; return c }
    /// Set allowed channel types (0=GuildText, 2=Voice, 4=Category, 5=News, 10=NewsThread, 11=PublicThread, 12=PrivateThread, 13=StageVoice)
    public func channelTypes(_ types: [Int]) -> ChannelSelectMenuBuilder { var c = self; c.channelTypes = types; return c }
    public func defaultChannels(_ ids: [ChannelID]) -> ChannelSelectMenuBuilder { var c = self; c.defaultChannelIds = ids; return c }
    public func disabled(_ d: Bool = true) -> ChannelSelectMenuBuilder { var c = self; c.disabled = d; return c }
    public func build() -> MessageComponent {
        MessageComponent.channelSelect(.init(custom_id: customId, placeholder: placeholder, disabled: disabled, channel_types: channelTypes, default_values: defaultChannelIds?.map { .init(id: $0.rawValue, type: .channel) }))
    }
}

/// A builder for creating text input components (for modals).
///
/// Use this builder to construct text inputs with validation.
///
/// ## Example
///
/// ```swift
/// let input = TextInputBuilder()
///     .customId("text_input")
///     .style(.short)
///     .label("Enter your name")
///     .placeholder("John Doe")
///     .build()
/// ```
public struct TextInputBuilder: Sendable {
    private var customId: String = ""
    private var style: MessageComponent.TextInput.Style = .short
    private var label: String = ""
    private var minLength: Int?
    private var maxLength: Int?
    private var required: Bool?
    private var value: String?
    private var placeholder: String?
    
    /// Creates a new text input builder.
    public init() {}
    
    /// Sets the custom ID.
    public func customId(_ id: String) -> TextInputBuilder { var c = self; c.customId = id; return c }
    
    /// Sets the input style.
    public func style(_ s: MessageComponent.TextInput.Style) -> TextInputBuilder { var c = self; c.style = s; return c }
    
    /// Sets the label.
    public func label(_ t: String) -> TextInputBuilder { var c = self; c.label = t; return c }
    
    /// Sets the minimum length.
    public func minLength(_ v: Int) -> TextInputBuilder { var c = self; c.minLength = v; return c }
    
    /// Sets the maximum length.
    public func maxLength(_ v: Int) -> TextInputBuilder { var c = self; c.maxLength = v; return c }
    
    /// Sets whether the input is required.
    public func required(_ r: Bool = true) -> TextInputBuilder { var c = self; c.required = r; return c }
    
    /// Sets the pre-filled value.
    public func value(_ v: String) -> TextInputBuilder { var c = self; c.value = v; return c }
    
    /// Sets the placeholder text.
    public func placeholder(_ p: String) -> TextInputBuilder { var c = self; c.placeholder = p; return c }
    
    /// Validates the text input configuration.
    public func validate() throws {
        if let min = minLength, let max = maxLength, min > max { throw ValidationError.invalidLength }
        if label.isEmpty { throw ValidationError.missingLabel }
        if customId.isEmpty { throw ValidationError.missingCustomId }
        if let max = maxLength, max > 4000 { throw ValidationError.maxLengthExceeded(max: 4000) }
        if let min = minLength, min < 0 { throw ValidationError.invalidLength }
    }
    
    /// Builds the text input.
    public func build() throws -> MessageComponent {
        try validate()
        return .textInput(.init(custom_id: customId, style: style, label: label, min_length: minLength, max_length: maxLength, required: required, value: value, placeholder: placeholder))
    }
    
    /// Validation errors for text input.
    public enum ValidationError: Error, Sendable { 
        case invalidLength
        case missingLabel
        case missingCustomId
        case maxLengthExceeded(max: Int)
    }
}

// MARK: - Modal Component Builders (added 2026)

public struct LabelBuilder: Sendable {
    private var label: String = ""
    private var description: String?
    private var components: [MessageComponent]?
    public init() {}
    public func label(_ t: String) -> LabelBuilder { var c = self; c.label = t; return c }
    public func description(_ d: String) -> LabelBuilder { var c = self; c.description = d; return c }
    public func components(_ comps: [MessageComponent]) -> LabelBuilder { var c = self; c.components = comps; return c }
    public func build() -> MessageComponent {
        .label(.init(label: label, description: description, components: components))
    }
}

public struct RadioGroupBuilder: Sendable {
    private var customId: String = ""
    private var options: [MessageComponent.RadioGroup.RadioOption] = []
    private var required: Bool?
    public init() {}
    public func customId(_ id: String) -> RadioGroupBuilder { var c = self; c.customId = id; return c }
    public func option(label: String, value: String, description: String? = nil, isDefault: Bool? = nil) -> RadioGroupBuilder {
        var c = self
        c.options.append(.init(label: label, value: value, description: description, isDefault: isDefault))
        return c
    }
    public func required(_ r: Bool = true) -> RadioGroupBuilder { var c = self; c.required = r; return c }
    public func build() -> MessageComponent {
        .radioGroup(.init(custom_id: customId, options: options, required: required))
    }
}

public struct CheckboxGroupBuilder: Sendable {
    private var customId: String = ""
    private var options: [MessageComponent.CheckboxGroup.CheckboxOption] = []
    private var minValues: Int?
    private var maxValues: Int?
    public init() {}
    public func customId(_ id: String) -> CheckboxGroupBuilder { var c = self; c.customId = id; return c }
    public func option(label: String, value: String, description: String? = nil, isDefault: Bool? = nil) -> CheckboxGroupBuilder {
        var c = self
        c.options.append(.init(label: label, value: value, description: description, isDefault: isDefault))
        return c
    }
    public func minValues(_ v: Int) -> CheckboxGroupBuilder { var c = self; c.minValues = v; return c }
    public func maxValues(_ v: Int) -> CheckboxGroupBuilder { var c = self; c.maxValues = v; return c }
    public func build() -> MessageComponent {
        .checkboxGroup(.init(custom_id: customId, options: options, minValues: minValues, maxValues: maxValues))
    }
}

public struct CheckboxBuilder: Sendable {
    private var customId: String = ""
    private var required: Bool?
    private var isDefault: Bool?
    public init() {}
    public func customId(_ id: String) -> CheckboxBuilder { var c = self; c.customId = id; return c }
    public func required(_ r: Bool = true) -> CheckboxBuilder { var c = self; c.required = r; return c }
    public func `default`(_ d: Bool = true) -> CheckboxBuilder { var c = self; c.isDefault = d; return c }
    public func build() -> MessageComponent {
        .checkbox(.init(custom_id: customId, required: required, isDefault: isDefault))
    }
}

public struct FileUploadBuilder: Sendable {
    private var customId: String = ""
    private var label: String = ""
    private var minLength: Int?
    private var maxLength: Int?
    private var required: Bool?
    private var placeholder: String?
    public init() {}
    public func customId(_ id: String) -> FileUploadBuilder { var c = self; c.customId = id; return c }
    public func label(_ t: String) -> FileUploadBuilder { var c = self; c.label = t; return c }
    public func minLength(_ v: Int) -> FileUploadBuilder { var c = self; c.minLength = v; return c }
    public func maxLength(_ v: Int) -> FileUploadBuilder { var c = self; c.maxLength = v; return c }
    public func required(_ r: Bool = true) -> FileUploadBuilder { var c = self; c.required = r; return c }
    public func placeholder(_ p: String) -> FileUploadBuilder { var c = self; c.placeholder = p; return c }
    public func build() -> MessageComponent {
        .fileUpload(.init(custom_id: customId, label: label, min_length: minLength, max_length: maxLength, required: required, placeholder: placeholder))
    }
}

/// A builder for creating action row components.
///
/// Action rows are containers that hold other components (buttons, select menus, etc.).
///
/// ## Example
///
/// ```swift
/// let button = ButtonBuilder().style(.primary).label("Click").customId("btn").build()
/// let row = ActionRowBuilder().add(button).build()
/// ```
public struct ActionRowBuilder: Sendable {
    private var components: [MessageComponent] = []
    
    /// Creates a new action row builder.
    public init() {}
    
    /// Adds a component to the action row.
    public func add(_ component: MessageComponent) -> ActionRowBuilder { var c = self; c.components.append(component); return c }
    
    /// Builds the action row.
    public func build() -> MessageComponent { .actionRow(.init(components: components)) }
}

/// A builder for creating multiple action rows.
///
/// Use this builder to construct a complete set of components for a message or modal.
///
/// ## Example
///
/// ```swift
/// let components = ComponentsBuilder()
///     .row { row in
///         let button = ButtonBuilder().style(.primary).label("Click").customId("btn").build()
///         row.add(button)
///     }
///     .build()
/// ```
public struct ComponentsBuilder: Sendable {
    private var rows: [MessageComponent.ActionRow] = []
    
    /// Creates a new components builder.
    public init() {}
    
    /// Adds a row to the components.
    public mutating func row(_ configure: @Sendable (inout ActionRowBuilder) -> Void) -> ComponentsBuilder {
        var rb = ActionRowBuilder()
        configure(&rb)
        if case let .actionRow(row) = rb.build() {
            rows.append(row)
        }
        return self
    }
    
    /// Builds all rows.
    public func build() -> [MessageComponent] { rows.map { .actionRow($0) } }
}
