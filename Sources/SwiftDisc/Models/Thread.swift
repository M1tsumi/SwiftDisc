import Foundation

/// Represents a thread member.
///
/// Thread members represent a user's membership in a thread channel.
///
/// ## Example
///
/// ```swift
/// if let members = thread.members {
///     for member in members {
///         print("User ID: \(member.user_id ?? "unknown")")
///         print("Joined: \(member.join_timestamp)")
///     }
/// }
/// ```
public struct ThreadMember: Codable, Hashable, Sendable {
    /// The thread ID.
    public let id: ChannelID?
    
    /// The user ID.
    public let user_id: UserID?
    
    /// When the user joined the thread (ISO 8601 timestamp).
    public let join_timestamp: String
    
    /// Thread member flags.
    public let flags: Int
    
    /// The guild member object for this thread member.
    public let member: GuildMember?
}

/// Response from the thread list endpoint.
///
/// Contains a paginated list of threads and their members.
///
/// ## Example
///
/// ```swift
/// let response = try await client.listActiveThreads(guildId: guildId)
/// print("Threads: \(response.threads.count)")
/// if response.has_more {
///     print("More threads available")
/// }
/// ```
public struct ThreadListResponse: Codable, Hashable, Sendable {
    /// The threads in this page.
    public let threads: [Channel]
    
    /// The thread members for these threads.
    public let members: [ThreadMember]
    
    /// Whether there are more threads available.
    public let has_more: Bool
}
