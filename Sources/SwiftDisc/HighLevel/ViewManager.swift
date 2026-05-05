import Foundation

public typealias ViewHandler = @Sendable (Interaction, DiscordClient) async -> Void

/// Pattern matching type for view custom_id routing.
public enum MatchType: Sendable {
    case exact
    case prefix
    case regex
}

/// A persistent view with handlers keyed by `custom_id` or matching prefixes.
/// Marked `@unchecked Sendable` because the `state` dictionary uses `Any`
/// values; callers are responsible for thread-safe state access.
public struct View: @unchecked Sendable {
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
            let task = Task.detached { @Sendable in
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
                        _ = try? await client.editMessage(channelId: channelId, messageId: messageId, components: disabled)
                    }
                } catch {
                    print("[ViewManager] Failed to disable components for view '\(id)' (msg:\(messageId)): \(error)")
                }
            }
        }
    }
    
    /// List active view ids.
    public func list() -> [String] { Array(views.keys) }
    
    /// Start listening to the client's event stream and route component interactions.
    nonisolated public func start(client: DiscordClient) {
        Task { @Sendable in
            // do not start twice
            if await listeningTask != nil { return }
            let task = Task.detached { @Sendable in
                let eventStream = await client.events
                for await event in eventStream {
                    switch event {
                    case .interactionCreate(let interaction):
                        if let data = interaction.data, let cid = data.custom_id {
                            await self.routeInteraction(customId: cid, interaction: interaction, client: client)
                        }
                    default: break
                    }
                }
            }
            await setListeningTask(task)
        }
    }
    
    private func setListeningTask(_ task: Task<Void, Never>) {
        listeningTask = task
    }
    
    internal func routeInteraction(customId: String, interaction: Interaction, client: DiscordClient) async {
        let snapshot = Array(views)
        var oneShotToRemove: [String] = []

        for (vid, view) in snapshot {
            var matched = false
            for (pattern, matchType, handler) in view.patterns {
                switch matchType {
                case .exact:
                    if pattern == customId { matched = true; Task { @Sendable in await handler(interaction, client) } }
                case .prefix:
                    if customId.hasPrefix(pattern) { matched = true; Task { @Sendable in await handler(interaction, client) } }
                case .regex:
                    do {
                        let regex = try NSRegularExpression(pattern: pattern)
                        let range = NSRange(location: 0, length: customId.utf16.count)
                        if regex.firstMatch(in: customId, options: [], range: range) != nil { matched = true; Task { @Sendable in await handler(interaction, client) } }
                    } catch {
                        print("[ViewManager] Invalid regex '\(pattern)' for view '\(vid)': \(error)")
                    }
                }
                if matched {
                    if view.oneShot { oneShotToRemove.append(vid) }
                    break
                }
            }
        }

        for id in oneShotToRemove {
            unregister(id)
        }
    }
    
    // Disable interactive components (buttons/selects) throughout a component tree.
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
            case .userSelect(let us):
                return .userSelect(.init(custom_id: us.custom_id, placeholder: us.placeholder, min_values: us.min_values, max_values: us.max_values, disabled: true, default_values: us.default_values))
            case .roleSelect(let rs):
                return .roleSelect(.init(custom_id: rs.custom_id, placeholder: rs.placeholder, min_values: rs.min_values, max_values: rs.max_values, disabled: true, default_values: rs.default_values))
            case .mentionableSelect(let ms):
                return .mentionableSelect(.init(custom_id: ms.custom_id, placeholder: ms.placeholder, min_values: ms.min_values, max_values: ms.max_values, disabled: true, default_values: ms.default_values))
            case .channelSelect(let cs):
                return .channelSelect(.init(custom_id: cs.custom_id, placeholder: cs.placeholder, min_values: cs.min_values, max_values: cs.max_values, disabled: true, channel_types: cs.channel_types, default_values: cs.default_values))
            case .textInput(let ti):
                return .textInput(ti)
            case .label(let l):
                return .label(l)
            case .radioGroup(let rg):
                return .radioGroup(rg)
            case .checkboxGroup(let cg):
                return .checkboxGroup(cg)
            case .checkbox(let cb):
                return .checkbox(cb)
            case .fileUpload(let fu):
                return .fileUpload(fu)
            }
        }
    }

}
