import Foundation

public struct GuildMember: Codable, Hashable {
    public let user: User?
    public let nick: String?
    public let avatar: String?
    public let roles: [RoleID]
    public let joined_at: String?
    public let deaf: Bool?
    public let mute: Bool?
    /// Effective permissions bitfield (decimal string) included by Discord in
    /// interaction payloads and some gateway member events.
    public let permissions: String?
}
