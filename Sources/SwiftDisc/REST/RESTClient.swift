//
//  RESTClient.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// REST API client for Discord API
public class RESTClient {
    private let httpClient: HTTPClient

    /// Initialize REST client
    /// - Parameter token: Bot token for authentication
    public init(token: String) {
        let config = DiscordConfiguration()
        self.httpClient = HTTPClient(token: token, configuration: config)
    }

    // MARK: - Entitlements Endpoints

    /// List entitlements for an application
    public func getEntitlements(
        userId: Snowflake? = nil,
        skuIds: [Snowflake]? = nil,
        before: Snowflake? = nil,
        after: Snowflake? = nil,
        limit: Int? = nil,
        guildId: Snowflake? = nil,
        excludeEnded: Bool? = nil
    ) async throws -> [Entitlement] {
        var queryItems: [URLQueryItem] = []

        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId.description))
        }
        if let skuIds = skuIds {
            for skuId in skuIds {
                queryItems.append(URLQueryItem(name: "sku_ids", value: skuId.description))
            }
        }
        if let before = before {
            queryItems.append(URLQueryItem(name: "before", value: before.description))
        }
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after.description))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let guildId = guildId {
            queryItems.append(URLQueryItem(name: "guild_id", value: guildId.description))
        }
        if let excludeEnded = excludeEnded {
            queryItems.append(URLQueryItem(name: "exclude_ended", value: excludeEnded ? "true" : "false"))
        }

        let path = "/applications/@me/entitlements" + (queryItems.isEmpty ? "" : "?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&"))
        return try await httpClient.get(path)
    }

    /// Get SKUs for an application
    public func getSKUs() async throws -> [SKU] {
        return try await httpClient.get("/applications/@me/skus")
    }

    /// Consume an entitlement
    public func consumeEntitlement(entitlementId: Snowflake) async throws {
        try await httpClient.post("/applications/@me/entitlements/\(entitlementId)/consume", body: EmptyBody())
    }

    // MARK: - Soundboard Endpoints

    /// List soundboard sounds for a guild
    public func getSoundboardSounds(guildId: Snowflake) async throws -> [SoundboardSound] {
        return try await httpClient.get("/guilds/\(guildId)/soundboard-sounds")
    }

    /// Create a guild soundboard sound
    public func createGuildSoundboardSound(
        guildId: Snowflake,
        sound: CreateGuildSoundboardSound
    ) async throws -> SoundboardSound {
        return try await httpClient.post("/guilds/\(guildId)/soundboard-sounds", body: sound)
    }

    /// Modify a guild soundboard sound
    public func modifyGuildSoundboardSound(
        guildId: Snowflake,
        soundId: Snowflake,
        sound: ModifyGuildSoundboardSound
    ) async throws -> SoundboardSound {
        return try await httpClient.patch("/guilds/\(guildId)/soundboard-sounds/\(soundId)", body: sound)
    }

    /// Delete a guild soundboard sound
    public func deleteGuildSoundboardSound(guildId: Snowflake, soundId: Snowflake) async throws {
        try await httpClient.delete("/guilds/\(guildId)/soundboard-sounds/\(soundId)")
    }

    /// Send a soundboard sound
    public func sendSoundboardSound(channelId: Snowflake, soundId: Snowflake, sourceGuildId: Snowflake? = nil) async throws {
        var body: [String: Any] = ["sound_id": soundId.description]
        if let sourceGuildId = sourceGuildId {
            body["source_guild_id"] = sourceGuildId.description
        }
        try await httpClient.post("/channels/\(channelId)/send-soundboard-sound", body: body)
    }

    // MARK: - Poll Endpoints

    /// Create a poll in a message
    public func createMessagePoll(
        channelId: Snowflake,
        poll: CreateMessagePoll
    ) async throws -> Message {
        return try await httpClient.post("/channels/\(channelId)/messages", body: ["poll": poll])
    }

    /// End a poll
    public func endPoll(channelId: Snowflake, messageId: Snowflake) async throws -> Message {
        return try await httpClient.post("/channels/\(channelId)/messages/\(messageId)/polls/end", body: EmptyBody())
    }

    /// Get poll voters
    public func getPollVoters(
        channelId: Snowflake,
        messageId: Snowflake,
        answerId: Int,
        after: Snowflake? = nil,
        limit: Int? = nil
    ) async throws -> [PollVoter] {
        var queryItems: [URLQueryItem] = []
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after.description))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        let path = "/channels/\(channelId)/messages/\(messageId)/polls/answers/\(answerId)" +
                   (queryItems.isEmpty ? "" : "?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&"))
        return try await httpClient.get(path)
    }

    // MARK: - User Profile Endpoints

    /// Get user connections
    public func getUserConnections() async throws -> [UserConnection] {
        return try await httpClient.get("/users/@me/connections")
    }

    /// Get user application role connection
    public func getUserApplicationRoleConnection(applicationId: Snowflake) async throws -> ApplicationRoleConnection {
        return try await httpClient.get("/users/@me/applications/\(applicationId)/role-connection")
    }

    /// Update user application role connection
    public func updateUserApplicationRoleConnection(
        applicationId: Snowflake,
        connection: ApplicationRoleConnection
    ) async throws -> ApplicationRoleConnection {
        return try await httpClient.put("/users/@me/applications/\(applicationId)/role-connection", body: connection)
    }

    // MARK: - Subscription Endpoints

    /// List subscriptions for an application
    public func listApplicationSubscriptions(
        userId: Snowflake? = nil,
        skuId: Snowflake? = nil,
        before: Snowflake? = nil,
        after: Snowflake? = nil,
        limit: Int? = nil
    ) async throws -> [Subscription] {
        var queryItems: [URLQueryItem] = []

        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId.description))
        }
        if let skuId = skuId {
            queryItems.append(URLQueryItem(name: "sku_id", value: skuId.description))
        }
        if let before = before {
            queryItems.append(URLQueryItem(name: "before", value: before.description))
        }
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after.description))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        let path = "/applications/@me/subscriptions" + (queryItems.isEmpty ? "" : "?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&"))
        return try await httpClient.get(path)
    }

    /// Get subscription info for a guild
    public func getSubscriptionInfo(guildId: Snowflake) async throws -> [Subscription] {
        return try await httpClient.get("/guilds/\(guildId)/subscriptions")
    }
}

/// Empty body for requests that don't need a body
private struct EmptyBody: Encodable {}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/REST/RESTClient.swift