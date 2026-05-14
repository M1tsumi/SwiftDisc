import Foundation

/// A three-state field for outgoing JSON payloads that distinguishes between
/// **absent**, **present-with-value**, and **present-with-null**.
///
/// Discord's PATCH endpoints rely on this distinction:
///
/// - Sending `{}` (field absent) means *do not change the field*.
/// - Sending `{"foo": null}` (explicit null) means *clear the field*.
/// - Sending `{"foo": "bar"}` (value) means *set the field to "bar"*.
///
/// Swift's plain `Optional` cannot express all three states because
/// `JSONEncoder` omits `Optional.none` by default. Use `OptionalField` for any
/// outgoing payload field where Discord requires explicit null to clear a
/// resource (for example, `parent_id` on channel edits, `content` on message
/// edits, `nick` on member edits, `expire_behavior` on integration edits).
///
/// ## Example
/// ```swift
/// struct EditMessage: Encodable {
///     var content: OptionalField<String>
///     var flags: OptionalField<Int>
/// }
///
/// // Do not change content; clear flags.
/// let body = EditMessage(content: .absent, flags: .null)
/// // Set content to "hi"; do not touch flags.
/// let body2 = EditMessage(content: .value("hi"), flags: .absent)
/// ```
///
/// ## Interaction with `JSONEncoder`
///
/// To make `.absent` actually be omitted from the encoded JSON, the containing
/// type must implement `encode(to:)` and call `encodeIfPresent` (or skip the
/// field entirely when `.absent`). Use the helper
/// ``Swift/KeyedEncodingContainer/encode(_:forKey:)-(OptionalField)`` provided
/// in this file, which handles all three cases automatically.
public enum OptionalField<Wrapped: Encodable & Sendable>: Encodable, Sendable {
    /// Field is absent from the payload (key omitted entirely).
    case absent
    /// Field is present with an explicit JSON `null`.
    case null
    /// Field is present with a value.
    case value(Wrapped)

    /// `true` if the field is absent from the payload.
    public var isAbsent: Bool {
        if case .absent = self { return true }
        return false
    }

    /// The wrapped value, or `nil` for `.absent` and `.null`.
    public var wrappedValue: Wrapped? {
        if case .value(let v) = self { return v }
        return nil
    }

    public func encode(to encoder: Encoder) throws {
        // Single-value fallback. The preferred path is via the keyed-container
        // overload below, which handles `.absent` by skipping the key.
        var container = encoder.singleValueContainer()
        switch self {
        case .absent:
            // No way to represent "absent" through a single-value container, so
            // fall back to null. Callers that need true omission must use the
            // keyed-container helper.
            try container.encodeNil()
        case .null:
            try container.encodeNil()
        case .value(let v):
            try container.encode(v)
        }
    }
}

extension OptionalField: Equatable where Wrapped: Equatable {}
extension OptionalField: Hashable where Wrapped: Hashable {}

extension OptionalField: ExpressibleByNilLiteral {
    /// `nil` literal maps to `.absent`. To send explicit JSON null, write
    /// `.null` explicitly.
    public init(nilLiteral: ()) { self = .absent }
}

public extension KeyedEncodingContainer {
    /// Encodes an `OptionalField`, omitting the key when the field is absent
    /// and writing JSON `null` when the field is `.null`.
    mutating func encode<Wrapped>(_ value: OptionalField<Wrapped>, forKey key: Key) throws {
        switch value {
        case .absent:
            return
        case .null:
            try encodeNil(forKey: key)
        case .value(let v):
            try encode(v, forKey: key)
        }
    }
}
