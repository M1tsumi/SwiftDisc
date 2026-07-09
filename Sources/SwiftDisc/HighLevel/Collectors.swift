import Foundation

// AsyncStream-based collectors and paginators for common patterns.
public extension DiscordClient {
    /// Stream messages for a given channel that match the provided filter.
    /// - Parameters:
    ///   - channelId: optional channel to restrict to (nil = all channels)
    ///   - timeout: optional timeout after which the stream finishes
    ///   - maxMessages: optional maximum number of messages to collect
    ///   - filter: predicate to decide whether to yield a message
    ///   - onError: optional error handler called when the event stream encounters an error
    func createMessageCollector(channelId: ChannelID? = nil, timeout: TimeInterval? = nil, maxMessages: Int? = nil, filter: @escaping @Sendable (Message) -> Bool = { _ in true }, onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Message> {
        AsyncStream { continuation in
            var collected = 0
            var timeoutTask: Task<Void, Never>?
            let task = Task {
                for await event in self.events {
                    switch event {
                    case .messageCreate(let message):
                        if let cid = channelId, message.channel_id != cid { continue }
                        if filter(message) {
                            continuation.yield(message)
                            collected += 1
                            if let maxMessages, collected >= maxMessages {
                                continuation.finish()
                                timeoutTask?.cancel()
                                return
                            }
                        }
                    default: break
                    }
                }
                continuation.finish()
                timeoutTask?.cancel()
            }

            if let t = timeout {
                timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(t * 1_000_000_000))
                    continuation.finish()
                    task.cancel()
                }
            }
        }
    }

    /// Stream guild members via the paginated `listGuildMembers` endpoint.
    /// This yields members lazily and avoids manual paging logic.
    func streamGuildMembers(guildId: GuildID, pageLimit: Int = 1000, onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildMember> {
        AsyncStream(GuildMember.self) { continuation in
            var task: Task<Void, Never>?
            task = Task {
                defer { task = nil }
                var after: UserID? = nil
                var lastSeen: String? = nil
                while true {
                    do {
                        let page = try await listGuildMembers(guildId: guildId, limit: pageLimit, after: after)
                        if page.isEmpty { break }
                        for m in page { continuation.yield(m) }
                        if let last = page.last?.user?.id.description {
                            if last == lastSeen { break }
                            lastSeen = last
                            after = page.last?.user?.id
                        } else { break }
                    } catch {
                        onError(error)
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Typed event streams

    /// A filtered `AsyncStream` that yields only incoming `Message` objects.
    ///
    /// Equivalent to listening to `events` and matching `.messageCreate`, but
    /// without any boilerplate switch statement.
    /// ```swift
    /// for await message in await client.messageEvents() {
    ///     print(message.content ?? "")
    /// }
    /// ```
    private func filteredEventStream<T>(_ match: @escaping @Sendable (DiscordEvent) -> T?) -> AsyncStream<T> {
        AsyncStream { continuation in
            let task = Task {
                for await event in self.events {
                    if let value = match(event) {
                        continuation.yield(value)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func messageEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Message> {
        filteredEventStream { if case .messageCreate(let msg) = $0 { return msg } else { return nil } }
    }

    /// A filtered `AsyncStream` that yields every `MessageReactionAdd` event.
    func reactionAddEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<MessageReactionAdd> {
        filteredEventStream { if case .messageReactionAdd(let ev) = $0 { return ev } else { return nil } }
    }

    /// A filtered `AsyncStream` that yields every incoming `Interaction`.
    func interactionEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Interaction> {
        filteredEventStream { if case .interactionCreate(let interaction) = $0 { return interaction } else { return nil } }
    }

    /// A filtered `AsyncStream` that yields `GuildMemberAdd` events.
    func memberAddEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildMemberAdd> {
        filteredEventStream { if case .guildMemberAdd(let ev) = $0 { return ev } else { return nil } }
    }

    /// A filtered `AsyncStream` that yields `GuildMemberRemove` events.
    func memberRemoveEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildMemberRemove> {
        filteredEventStream { if case .guildMemberRemove(let ev) = $0 { return ev } else { return nil } }
    }

    /// A filtered `AsyncStream` that yields `PresenceUpdate` events.
    func presenceUpdateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<PresenceUpdate> {
        filteredEventStream { if case .presenceUpdate(let ev) = $0 { return ev } else { return nil } }
    }

    // MARK: - New event collectors
    
    /// A filtered `AsyncStream` that yields thread create events.
    func threadCreateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Channel> {
        filteredEventStream { if case .threadCreate(let ch) = $0 { return ch } else { return nil } }
    }
    
    /// A filtered `AsyncStream` that yields thread update events.
    func threadUpdateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Channel> {
        filteredEventStream { if case .threadUpdate(let ch) = $0 { return ch } else { return nil } }
    }
    
    /// A filtered `AsyncStream` that yields thread delete events.
    func threadDeleteEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Channel> {
        filteredEventStream { if case .threadDelete(let ch) = $0 { return ch } else { return nil } }
    }
    
    /// A filtered `AsyncStream` that yields guild role create events.
    func roleCreateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildRoleCreate> {
        filteredEventStream { if case .guildRoleCreate(let ev) = $0 { return ev } else { return nil } }
    }
    
    /// A filtered `AsyncStream` that yields guild role update events.
    func roleUpdateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildRoleUpdate> {
        filteredEventStream { if case .guildRoleUpdate(let ev) = $0 { return ev } else { return nil } }
    }
    
    /// A filtered `AsyncStream` that yields guild role delete events.
    func roleDeleteEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildRoleDelete> {
        filteredEventStream { if case .guildRoleDelete(let ev) = $0 { return ev } else { return nil } }
    }
    
    /// A filtered `AsyncStream` that yields guild emoji update events.
    func emojiUpdateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildEmojisUpdate> {
        filteredEventStream { if case .guildEmojisUpdate(let ev) = $0 { return ev } else { return nil } }
    }
    
    /// A filtered `AsyncStream` that yields typing start events.
    func typingStartEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<TypingStart> {
        filteredEventStream { if case .typingStart(let ev) = $0 { return ev } else { return nil } }
    }
    
    /// A filtered `AsyncStream` that yields message update events.
    func messageUpdateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Message> {
        filteredEventStream { if case .messageUpdate(let msg) = $0 { return msg } else { return nil } }
    }
    
    /// A filtered `AsyncStream` that yields message delete events.
    func messageDeleteEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<MessageDelete> {
        filteredEventStream { if case .messageDelete(let ev) = $0 { return ev } else { return nil } }
    }
}
