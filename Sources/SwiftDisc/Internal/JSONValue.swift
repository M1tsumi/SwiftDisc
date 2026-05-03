import Foundation

public enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case int(Int)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .number(v); return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode([String: JSONValue].self) { self = .object(v); return }
        if let v = try? container.decode([JSONValue].self) { self = .array(v); return }
        self = .null
    }

    /// Returns a plain-string representation of a scalar JSONValue, or nil for objects/arrays/null.
    public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .number(let n): return String(n)
        case .bool(let b): return String(b)
        default: return nil
        }
    }

    /// Returns an Int value if the JSONValue is an int, or nil otherwise.
    public var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    /// Returns a Double value if the JSONValue is a number or int, or nil otherwise.
    public var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .int(let i): return Double(i)
        default: return nil
        }
    }

    /// Returns a Bool value if the JSONValue is a bool, or nil otherwise.
    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    /// Returns the array if the JSONValue is an array, or nil otherwise.
    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    /// Returns the object dictionary if the JSONValue is an object, or nil otherwise.
    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// Returns true if the JSONValue is null.
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// Subscript access for object values. Returns nil if not an object or key not found.
    public subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }

    /// Subscript access for array values. Returns nil if not an array or index out of bounds.
    public subscript(index: Int) -> JSONValue? {
        guard index >= 0, let array = arrayValue, index < array.count else { return nil }
        return array[index]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .int(let i): try container.encode(i)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
}
