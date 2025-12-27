import Foundation

public typealias ViewHandler = (Interaction, DiscordClient) async -> Void

public enum MatchType {
    case exact
    case prefix
    case regex
}

/// A persistent view with handlers keyed by `custom_id` or matching prefixes.
public struct View {
    public let id: String
    public let timeout: TimeInterval?
    /// Patterns: (pattern string, match type, handler)
    public var patterns: [(String, MatchType, ViewHandler)]
    public let oneShot: Bool
    /// Optional list of messages (channelId, messageId) to edit on expire (disable components)
    public let editOnExpire: [(ChannelID, MessageID)]?
    /// Per-view mutable storage for stateful views
    public var state: [String: Any] = [:]
    
    public init(id: String = UUID().uuidString, timeout: TimeInterval? = nil, handlers: [String: ViewHandler] = [:], patterns: [(String, MatchType, ViewHandler)] = [], oneShot: Bool = false, editOnExpire: [(ChannelID, MessageID)]? = nil) {
        self.id = id
        self.timeout = timeout
        self.oneShot = oneShot
        self.editOnExpire = editOnExpire
        // Convert simple handlers dict to exact-match patterns
        var p = handlers.map { ($0.key, MatchType.exact, $0.value) }
        p.append(contentsOf: patterns)
        self.patterns = p
    }
}

/// Manages registered views and routes component interactions to view handlers.
public actor ViewManager {
    private var views: [String: View] = [:]
    private var expiryTasks: [String: Task<Void, Never>] = [:]
    private var listeningTask: Task<Void, Never>?
    
    public init() {}
    
    /// Register a view and schedule expiration if a timeout is set.
    public func register(_ view: View, client: DiscordClient) {
        views[view.id] = view
        if let t = view.timeout {
            let id = view.id
            let task = Task.detached { [weak client] in
                try? await Task.sleep(nanoseconds: UInt64(t * 1_000_000_000))
                await self.expireView(id: id, client: client)
            }
            expiryTasks[view.id] = task
        }
    }
    
    /// Unregister a view by id.
    public func unregister(_ id: String) {
        views.removeValue(forKey: id)
        if let task = expiryTasks.removeValue(forKey: id) { task.cancel() }
    }
    
    /// Expire a view and perform lifecycle cleanup (editing messages, removing handlers).
    private func expireView(id: String, client: DiscordClient?) async {
        guard let view = views.removeValue(forKey: id) else { return }
        expiryTasks.removeValue(forKey: id)?.cancel()
        // On expire: optionally edit messages to disable components
        if let refs = view.editOnExpire, let client = client {
            for (channelId, messageId) in refs {
                do {
                    let msg = try await client.getMessage(channelId: channelId, messageId: messageId)
                    if let comps = msg.components {
                        let disabled = disableComponents(comps)
                        try? await client.editMessage(channelId: channelId, messageId: messageId, components: disabled)
                    }
                } catch {
                    // ignore errors on cleanup
                }
            }
        }
    }
    
    /// List active view ids.
    public func list() -> [String] { Array(views.keys) }
    
    /// Start listening to the client's event stream and route component interactions.
    public func start(client: DiscordClient) {
        // do not start twice
        if listeningTask != nil { return }
        listeningTask = Task.detached { [weak client] in
            guard let client else { return }
            for await event in client.events {
                switch event {
                case .interactionCreate(let interaction):
                    if let data = interaction.data, let cid = data.custom_id {
                        await self.routeInteraction(customId: cid, interaction: interaction, client: client)
                    }
                default: break
                }
            }
        }
    }
    
    private func routeInteraction(customId: String, interaction: Interaction, client: DiscordClient) async {
        for (vid, view) in views {
            var matched = false
            for (pattern, matchType, handler) in view.patterns {
                switch matchType {
                case .exact:
                    if pattern == customId { matched = true; Task { await handler(interaction, client) } }
                case .prefix:
                    if customId.hasPrefix(pattern) { matched = true; Task { await handler(interaction, client) } }
                case .regex:
                    do {
                        let regex = try NSRegularExpression(pattern: pattern)
                        let range = NSRange(location: 0, length: customId.utf16.count)
                        if regex.firstMatch(in: customId, options: [], range: range) != nil { matched = true; Task { await handler(interaction, client) } }
                    } catch { }
                }
                if matched {
                    if view.oneShot { await unregister(vid) }
                    break
                }
            }
        }
    }
    
    // Helper: disable interactive components (buttons/selects) in a component tree
    private func disableComponents(_ comps: [MessageComponent]) -> [MessageComponent] {
        return comps.map { comp in
            switch comp {
            case .actionRow(let row):
                let nested = disableComponents(row.components)
                return .actionRow(.init(components: nested))
            case .button(let btn):
                return .button(.init(style: btn.style, label: btn.label, custom_id: btn.custom_id, url: btn.url, disabled: true))
            case .select(let sel):
                return .select(.init(custom_id: sel.custom_id, options: sel.options, placeholder: sel.placeholder, min_values: sel.min_values, max_values: sel.max_values, disabled: true))
            case .textInput(let ti):
                return .textInput(ti)
            }
        }
    }

}
