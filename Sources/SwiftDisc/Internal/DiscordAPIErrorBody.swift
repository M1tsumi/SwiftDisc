import Foundation

/// A parsed Discord API error body.
///
/// Discord returns 4xx/5xx responses with a JSON body of the shape:
/// ```json
/// { "code": 50035, "message": "Invalid Form Body",
///   "errors": { "embeds": { "0": { "fields": { "1": { "name": {
///     "_errors": [
///       { "code": "BASE_TYPE_REQUIRED", "message": "This field is required" }
///     ] } } } } } } }
/// ```
///
/// `DiscordAPIErrorBody` exposes the top-level `code` and `message`, plus a
/// flattened ``validationErrors`` list — one entry per leaf `_errors` array,
/// with the JSON pointer-style path that produced it. This makes it trivial to
/// surface actionable diagnostics to bot developers without traversing the
/// nested tree by hand.
public struct DiscordAPIErrorBody: Sendable, Equatable {
    /// Top-level Discord error code (see <https://discord.com/developers/docs/topics/opcodes-and-status-codes#json>).
    public let code: Int?

    /// Human-readable message, e.g. `"Invalid Form Body"`.
    public let message: String

    /// Flattened list of leaf validation errors. Empty when the response is a
    /// generic API error rather than a form-validation failure.
    public let validationErrors: [ValidationError]

    /// One leaf entry from Discord's nested `errors` tree.
    public struct ValidationError: Sendable, Equatable {
        /// Dotted path to the offending field, e.g. `"embeds.0.fields.1.name"`.
        public let path: String
        /// Discord's error code for this leaf, e.g. `"BASE_TYPE_REQUIRED"`.
        public let code: String
        /// Human-readable explanation, e.g. `"This field is required"`.
        public let message: String

        public init(path: String, code: String, message: String) {
            self.path = path
            self.code = code
            self.message = message
        }
    }

    public init(code: Int?, message: String, validationErrors: [ValidationError] = []) {
        self.code = code
        self.message = message
        self.validationErrors = validationErrors
    }

    /// Attempts to parse a Discord API error body from raw response data.
    /// Returns `nil` if the data is not a recognizable Discord error JSON.
    public static func parse(from data: Data) -> DiscordAPIErrorBody? {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let code = object["code"] as? Int
        guard let message = object["message"] as? String else { return nil }

        var leaves: [ValidationError] = []
        if let errorsTree = object["errors"] as? [String: Any] {
            collectValidationErrors(node: errorsTree, path: "", into: &leaves)
        }
        return DiscordAPIErrorBody(code: code, message: message, validationErrors: leaves)
    }

    /// Recursively walks Discord's `errors` tree, collecting leaf `_errors` arrays.
    private static func collectValidationErrors(node: Any, path: String, into out: inout [ValidationError]) {
        guard let dict = node as? [String: Any] else { return }
        if let errs = dict["_errors"] as? [[String: Any]] {
            for entry in errs {
                let code = entry["code"] as? String ?? ""
                let message = entry["message"] as? String ?? ""
                out.append(ValidationError(path: path, code: code, message: message))
            }
            // `_errors` is a leaf marker; do not recurse further into siblings here
            // because Discord places `_errors` at the deepest level by convention.
            return
        }
        for (key, value) in dict {
            let nextPath = path.isEmpty ? key : "\(path).\(key)"
            collectValidationErrors(node: value, path: nextPath, into: &out)
        }
    }
}
