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
            let task = Task {
                do {
                    for await event in self.events {
                        switch event {
                        case .messageCreate(let message):
                            if let cid = channelId, message.channel_id != cid { continue }
                            if filter(message) {
                                continuation.yield(message)
                                collected += 1
                                if let maxMessages, collected >= maxMessages {
                                    continuation.finish()
                                    return
                                }
                            }
                        default: break
                        }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }

            if let t = timeout {
                Task {
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
            Task {
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
    func messageEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Message> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .messageCreate(let msg) = event { continuation.yield(msg) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }

    /// A filtered `AsyncStream` that yields every `MessageReactionAdd` event.
    func reactionAddEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<MessageReactionAdd> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .messageReactionAdd(let ev) = event { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }

    /// A filtered `AsyncStream` that yields every incoming `Interaction`.
    ///
    /// Useful for bots that handle interactions outside of `SlashCommandRouter`.
    func interactionEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Interaction> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .interactionCreate(let interaction) = event { continuation.yield(interaction) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }

    /// A filtered `AsyncStream` that yields `GuildMemberAdd` events.
    func memberAddEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildMemberAdd> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .guildMemberAdd(let ev) = event { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }

    /// A filtered `AsyncStream` that yields `GuildMemberRemove` events.
    func memberRemoveEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildMemberRemove> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .guildMemberRemove(let ev) = event { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }

    /// A filtered `AsyncStream` that yields `PresenceUpdate` events.
    func presenceUpdateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<PresenceUpdate> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .presenceUpdate(let ev) = event { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - New event collectors
    
    /// A filtered `AsyncStream` that yields thread create events.
    func threadCreateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Channel> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .threadCreate(let ch) = event { continuation.yield(ch) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
    
    /// A filtered `AsyncStream` that yields thread update events.
    func threadUpdateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Channel> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .threadUpdate(let ch) = event { continuation.yield(ch) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
    
    /// A filtered `AsyncStream` that yields thread delete events.
    func threadDeleteEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Channel> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .threadDelete(let ch) = event { continuation.yield(ch) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
    
    
    /// A filtered `AsyncStream` that yields guild role create events.
    func roleCreateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildRoleCreate> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .guildRoleCreate(let ev) = event { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
    
    /// A filtered `AsyncStream` that yields guild role update events.
    func roleUpdateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildRoleUpdate> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .guildRoleUpdate(let ev) = event { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
    
    /// A filtered `AsyncStream` that yields guild role delete events.
    func roleDeleteEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildRoleDelete> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .guildRoleDelete(let ev) = event { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
    
    /// A filtered `AsyncStream` that yields guild emoji update events.
    func emojiUpdateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<GuildEmojisUpdate> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .guildEmojisUpdate(let ev) = event { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
    
    /// A filtered `AsyncStream` that yields typing start events.
    func typingStartEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<TypingStart> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .typingStart(let ev) = event { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
    
    /// A filtered `AsyncStream` that yields message update events.
    func messageUpdateEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<Message> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .messageUpdate(let msg) = event { continuation.yield(msg) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
    
    /// A filtered `AsyncStream` that yields message delete events.
    func messageDeleteEvents(onError: @escaping @Sendable (Error) -> Void = { _ in }) -> AsyncStream<MessageDelete> {
        AsyncStream { continuation in
            Task {
                do {
                    for await event in self.events {
                        if case .messageDelete(let ev) = event { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    onError(error)
                    continuation.finish()
                }
            }
        }
    }
}
