import Foundation

// AsyncStream-based collectors and paginators for common patterns.
public extension DiscordClient {
    /// Stream messages for a given channel that match the provided filter.
    /// - Parameters:
    ///   - channelId: optional channel to restrict to (nil = all channels)
    ///   - timeout: optional timeout after which the stream finishes
    ///   - maxMessages: optional maximum number of messages to collect
    ///   - filter: predicate to decide whether to yield a message
    func createMessageCollector(channelId: ChannelID? = nil, timeout: TimeInterval? = nil, maxMessages: Int? = nil, filter: @escaping (Message) -> Bool = { _ in true }) -> AsyncStream<Message> {
        AsyncStream { continuation in
            var collected = 0
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
                                return
                            }
                        }
                    default: break
                    }
                }
                continuation.finish()
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
    func streamGuildMembers(guildId: GuildID, pageLimit: Int = 1000) -> AsyncStream<GuildMember> {
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
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            }
        }
    }
}
