import Foundation

public struct ButtonBuilder {
    public enum Style: Int { case primary = 1, secondary = 2, success = 3, danger = 4, link = 5 }
    private var style: Int = Style.primary.rawValue
    private var label: String?
    private var customId: String?
    private var url: String?
    private var disabled: Bool?
    public init() {}
    public func style(_ s: Style) -> ButtonBuilder { var c = self; c.style = s.rawValue; return c }
    public func label(_ t: String) -> ButtonBuilder { var c = self; c.label = t; return c }
    public func customId(_ id: String) -> ButtonBuilder { var c = self; c.customId = id; return c }
    public func url(_ u: String) -> ButtonBuilder { var c = self; c.url = u; return c }
    public func disabled(_ d: Bool = true) -> ButtonBuilder { var c = self; c.disabled = d; return c }
    public func build() -> MessageComponent {
        MessageComponent.button(.init(style: style, label: label, custom_id: customId, url: url, disabled: disabled))
    }
}

public struct SelectMenuBuilder {
    private var customId: String = ""
    private var options: [MessageComponent.SelectMenu.Option] = []
    private var placeholder: String?
    private var min: Int?
    private var max: Int?
    private var disabled: Bool?
    public init() {}
    public func customId(_ id: String) -> SelectMenuBuilder { var c = self; c.customId = id; return c }
    public func option(label: String, value: String, description: String? = nil, emoji: String? = nil, isDefault: Bool? = nil) -> SelectMenuBuilder {
        var c = self
        c.options.append(.init(label: label, value: value, description: description, emoji: emoji, default: isDefault))
        return c
    }
    public func placeholder(_ t: String) -> SelectMenuBuilder { var c = self; c.placeholder = t; return c }
    public func minValues(_ v: Int) -> SelectMenuBuilder { var c = self; c.min = v; return c }
    public func maxValues(_ v: Int) -> SelectMenuBuilder { var c = self; c.max = v; return c }
    public func disabled(_ d: Bool = true) -> SelectMenuBuilder { var c = self; c.disabled = d; return c }
    public func build() -> MessageComponent {
        MessageComponent.select(.init(custom_id: customId, options: options, placeholder: placeholder, min_values: min, max_values: max, disabled: disabled))
    }
}

public struct TextInputBuilder {
    private var customId: String = ""
    private var style: MessageComponent.TextInput.Style = .short
    private var label: String = ""
    private var minLength: Int?
    private var maxLength: Int?
    private var required: Bool?
    private var value: String?
    private var placeholder: String?
    public init() {}
    public func customId(_ id: String) -> TextInputBuilder { var c = self; c.customId = id; return c }
    public func style(_ s: MessageComponent.TextInput.Style) -> TextInputBuilder { var c = self; c.style = s; return c }
    public func label(_ t: String) -> TextInputBuilder { var c = self; c.label = t; return c }
    public func minLength(_ v: Int) -> TextInputBuilder { var c = self; c.minLength = v; return c }
    public func maxLength(_ v: Int) -> TextInputBuilder { var c = self; c.maxLength = v; return c }
    public func required(_ r: Bool = true) -> TextInputBuilder { var c = self; c.required = r; return c }
    public func value(_ v: String) -> TextInputBuilder { var c = self; c.value = v; return c }
    public func placeholder(_ p: String) -> TextInputBuilder { var c = self; c.placeholder = p; return c }
    public func validate() throws {
        if let min = minLength, let max = maxLength, min > max { throw ValidationError.invalidLength }
        if label.isEmpty { throw ValidationError.missingLabel }
        if customId.isEmpty { throw ValidationError.missingCustomId }
    }
    public func build() throws -> MessageComponent {
        try validate()
        return .textInput(.init(custom_id: customId, style: style, label: label, min_length: minLength, max_length: maxLength, required: required, value: value, placeholder: placeholder))
    }
    public enum ValidationError: Error { case invalidLength, missingLabel, missingCustomId }
}

public struct ActionRowBuilder {
    private var components: [MessageComponent] = []
    public init() {}
    public func add(_ component: MessageComponent) -> ActionRowBuilder { var c = self; c.components.append(component); return c }
    public func build() -> MessageComponent { .actionRow(.init(components: components)) }
}

public struct ComponentsBuilder {
    private var rows: [MessageComponent.ActionRow] = []
    public init() {}
    public mutating func row(_ configure: (inout ActionRowBuilder) -> Void) -> ComponentsBuilder {
        var rb = ActionRowBuilder()
        configure(&rb)
        if case let .actionRow(row) = rb.build() {
            rows.append(row)
        }
        return self
    }
    public func build() -> [MessageComponent] { rows.map { .actionRow($0) } }
}
