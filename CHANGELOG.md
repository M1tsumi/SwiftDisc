# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-04-08

### Overview
SwiftDisc 2.1.0 improves debugging and onboarding and hardens internal lifecycle
behavior. This release improves error clarity, adds rate-limit observability,
and refreshes contributor workflows with cleaner docs and reusable test fixtures.

### Added — Developer Experience
- **Clear `DiscordError` descriptions** — common REST, gateway, and validation
  failures now produce messages that are easier to read and act on.
- **Rate-limit observability** — `DiscordConfiguration.onRateLimit` can observe
  REST bucket updates and waits through a lightweight `RateLimitEvent` snapshot.
- **Shared test fixtures** — reusable helpers for `User`, `Message`, and
  interaction payloads reduce repeated JSON boilerplate in tests.
- **Contributor guide** — a top-level `CONTRIBUTING.md` documents workflow,
  build/test commands, and PR expectations.

### Changed
- **`DiscordConfiguration` docs** now explain the voice and gateway diagnostic
  toggles more clearly.
- **Documentation defaults** now use `DISCORD_BOT_TOKEN` consistently across the
  README onboarding flow and examples.
- **README roadmap** now frames the release as a reliability and developer
  experience update instead of a v2.0.0 carryover.
- **README header branding** restores the SwiftDisc SVG hero in the top section.
- **Internal actor ownership** was tightened by removing a few `nonisolated(unsafe)`
  patterns in the client, cache, and sharding manager.

### Fixed
- **Gateway URL construction** uses `URLComponents` for safe query parameter handling, preventing malformed URLs when `gatewayBaseURL` contains trailing slashes
- **Gateway reconnection loop** now has a maximum attempt limit (10) to prevent infinite retry loops

## [2.0.0] - 2026-03-02

### Overview
SwiftDisc 2.0.0 is a major release delivering a complete Swift 6 strict-concurrency
migration, typed throws throughout the REST layer, 32 new gateway event callbacks,
a fully expanded Guild model, critical bug fixes, and developer-experience
improvements including `message.reply()`, `client.sendDM()`, typed slash-option
accessors, `EmbedBuilder.timestamp(Date)`, a public `CooldownManager`, filtered
event-stream helpers, and a background cache-eviction task.

### Breaking Changes
- **`DiscordClient`** is now a `public actor` (was `public final class`). All method
  calls from outside the actor require `await`. Immutable `let` properties (`token`,
  `cache`) remain accessible without `await`.
- **`CommandRouter`**, **`SlashCommandRouter`**, **`AutocompleteRouter`**,
  **`ShardManager`** are now `actor` types. All mutating methods (e.g. `register`,
  `registerPath`, `useCommands`) require `await`.
- **`CooldownManager`** is now a `public actor`. `isOnCooldown` and `setCooldown`
  require `await`.
- All stored handler closures (`onReady`, `onMessage`, `onVoiceFrame`, `Handler`
  typealiases, etc.) are now `@Sendable`.
- `SwiftDiscExtension` protocol now requires `Sendable` conformance.
- `VoiceAudioSource` protocol now requires `Sendable` conformance.
- `WebSocketClient` protocol now requires `Sendable` conformance.
- `HTTPClient` REST methods now declare `throws(DiscordError)` instead of untyped
  `throws`. Call sites using `catch { }` will need to handle `DiscordError` directly.
- `Guild` model expanded from 4 fields to ~50 fields — any code that relied on the
  minimal stub may need to handle new optionals.

### Added — Developer Experience
- **`message.reply(...)`** — reply to any `Message` in one call. Sets
  `message_reference` automatically and optionally suppresses the mention:
  ```swift
  let response = try await message.reply(client: client, content: "Pong!")
  let quiet    = try await message.reply(client: client, content: "...", mention: false)
  ```
- **`client.sendDM(userId:content:embeds:components:)`** — open a DM channel and
  send a message in a single awaitable call, replacing the two-step
  `createDM` + `sendMessage` pattern:
  ```swift
  try await client.sendDM(userId: userId, content: "Welcome to the server!")
  ```
- **`SlashCommandRouter.Context` typed option accessors** — resolve Discord
  interaction option values to strongly-typed objects using the `resolved` map:
  ```swift
  let target     = ctx.user("target")       // → User?
  let destination = ctx.channel("channel") // → Interaction.ResolvedChannel?
  let role       = ctx.role("role")         // → Interaction.ResolvedRole?
  let file       = ctx.attachment("upload") // → Interaction.ResolvedAttachment?
  ```
- **`EmbedBuilder.timestamp(_ date: Date)`** — pass a `Date` directly instead of
  manually formatting an ISO 8601 string:
  ```swift
  EmbedBuilder().timestamp(Date()).build()
  ```
- **`CooldownManager`** is now `public` — use it directly in any bot code, not just
  inside the built-in command routers.
- **Filtered event-stream helpers** on `DiscordClient` — typed `AsyncStream`
  subscriptions without manual `switch event` boilerplate:
  ```swift
  for await message     in client.messageEvents()      { ... }
  for await reaction    in client.reactionAddEvents()  { ... }
  for await interaction in client.interactionEvents()  { ... }
  for await member      in client.memberAddEvents()    { ... }
  ```
- **`MessagePayload` fluent builder** — composable payload type covering every
  message-send option. Automatically dispatches to multipart when files are present:
  ```swift
  try await client.send(to: channelId, MessagePayload()
      .content("Hello!")
      .embed(EmbedBuilder().title("World").build())
      .ephemeral()
      .silent())
  try await client.edit(channelId: cid, messageId: mid, MessagePayload().content("Updated"))
  try await client.respond(to: interaction, with: MessagePayload().content("OK").ephemeral())
  ```
- **`WebhookClient`** — standalone token-free webhook client (uses `URLSession`
  directly, no bot token required). Parse from URL or supply ID + token directly:
  ```swift
  let hook = WebhookClient(url: "https://discord.com/api/webhooks/123/abc")!
  let msg  = try await hook.execute(content: "Hi!", wait: true)
  try await hook.editMessage(messageId: msg!.id.rawValue, content: "Updated")
  try await hook.deleteMessage(messageId: msg!.id.rawValue)
  ```
- **`EmojiRef` typed enum** — type-safe emoji references for all reaction APIs:
  ```swift
  try await client.addReaction(channelId: cid, messageId: mid, emoji: .unicode("👍"))
  try await client.addReaction(channelId: cid, messageId: mid, emoji: .custom(name: "uwu", id: emojiId))
  ```
- **`DiscordClient.archiveThread(channelId:locked:)`** — archive (and optionally
  lock) a thread in one call via `PATCH /channels/{id}`.
- **`DiscordClient.syncCommands(_:guildId:)`** — smart command sync that fetches
  existing commands, diffs the name sets, and only calls `bulkOverwrite` when there
  is an actual change. Avoids rate-limit churn on every restart:
  ```swift
  try await client.syncCommands(myCommands)            // global
  try await client.syncCommands(myCommands, guildId: guildId) // guild
  ```
- **Middleware for `CommandRouter` and `SlashCommandRouter`** — register
  cross-cutting concerns (logging, auth gates, rate-limiting) independently of
  command handlers:
  ```swift
  router.use { ctx, next in
      guard ctx.isAdmin else {
          try await ctx.message.reply(client: ctx.client, content: "🚫 Admins only.")
          return
      }
      try await next(ctx)
  }
  ```
- **Permission helpers on `Context`** — both `CommandRouter.Context` and
  `SlashCommandRouter.Context` gain `hasPermission(_:)`, `isAdmin`, and
  `memberHasRole(_:)`:
  ```swift
  guard ctx.isAdmin else { return }
  guard ctx.hasPermission(1 << 5) else { return } // MANAGE_MESSAGES
  guard ctx.memberHasRole(modRoleId) else { return }
  ```
- **Cache role + emoji storage** — `Cache` now stores per-guild roles and emojis:
  ```swift
  cache.upsert(role: role, guildId: guildId)
  let allRoles = cache.getRoles(guildId: guildId)
  cache.upsert(emojis: guild.emojis ?? [], guildId: guild.id)
  let emojis   = cache.getEmojis(guildId: guildId)
  ```
- **`GuildMember.permissions`** — added `permissions: String?` field that Discord
  includes in interaction and some gateway member payloads (effective permission
  bitfield as a decimal string).

### Added — Discord API Coverage
- **32 new gateway event callbacks** added to `DiscordClient` — every previously
  missing event now has a dedicated `@Sendable` callback property:
  - `onMessageDeleteBulk`, `onReactionAdd`, `onReactionRemove`,
    `onReactionRemoveAll`, `onReactionRemoveEmoji`
  - `onGuildUpdate`, `onGuildDelete`
  - `onGuildMemberAdd`, `onGuildMemberRemove`, `onGuildMemberUpdate`
  - `onChannelCreate`, `onChannelUpdate`, `onChannelDelete`
  - `onThreadCreate`, `onThreadUpdate`, `onThreadDelete`
  - `onGuildRoleCreate`, `onGuildRoleUpdate`, `onGuildRoleDelete`
  - `onGuildBanAdd`, `onGuildBanRemove`, `onAutoModerationActionExecution`
  - `onInteractionCreate`
  - `onTypingStart`, `onPresenceUpdate`, `onVoiceStateUpdate`
  - `onGuildScheduledEventCreate`, `onGuildScheduledEventUpdate`, `onGuildScheduledEventDelete`
  - `onPollVoteAdd`, `onPollVoteRemove`
  - `onEntitlementCreate`, `onEntitlementUpdate`, `onEntitlementDelete`
  - `onSoundboardSoundCreate`, `onSoundboardSoundUpdate`, `onSoundboardSoundDelete`
- **Full `Guild` model** — expanded from a 4-field stub to a complete ~50-field
  model matching Discord's `GUILD_CREATE` and REST guild response, including
  `roles`, `emojis`, `features`, `stickers`, `members`, `channels`, `threads`,
  `presences`, `stage_instances`, `guild_scheduled_events`, and more.
- **`EventDispatcher` full rewire** — all previously-stubbed `break` dispatches now
  invoke the appropriate callbacks. `GUILD_CREATE` seeds the full channel, thread,
  and member user cache. Presence, member, and thread events update the cache.

### Fixed
- **HTTPClient double-wrap bug** — errors thrown inside the inner `do {}` block
  (e.g. `DiscordError.decoding`, `.http`, `.api`) were being caught by the outer
  `catch {}` and re-wrapped as `DiscordError.network(DiscordError.xxx)`. Fixed by
  inserting `catch let de as DiscordError { throw de }` before each generic catch.
- **Soundboard gateway event names** — three event strings were incorrect, causing
  soundboard events to be silently dropped:
  - `SOUND_BOARD_SOUND_CREATE/UPDATE/DELETE` → `SOUNDBOARD_SOUND_CREATE/UPDATE/DELETE`
- **`DiscordError` not `Sendable`** — error values could not safely cross actor
  boundaries. Added explicit `Sendable` conformance.

### Changed — Concurrency Architecture
- **`Package.swift`**: upgraded to `swift-tools-version:6.2` with
  `.swiftLanguageMode(.v6)` for both `SwiftDisc` and `SwiftDiscTests` targets.
- **`DiscordClient`**: converted to `actor`. Callback properties typed as
  `@Sendable`. All REST and gateway methods are actor-isolated async. `let`
  properties are `nonisolated`.
- **`CommandRouter`**, **`SlashCommandRouter`**, **`AutocompleteRouter`**: converted
  to `actor`. `Handler` typealiases updated to `@Sendable`. `Context` types conform
  to `Sendable`. Static helpers marked `nonisolated`.
- **`ShardManager`**: converted to `actor`.
- **`CooldownManager`**: replaced `NSLock`-guarded `final class` with a clean
  `public actor`. All synchronization is now compiler-enforced.
- **`EventDispatcher`**: all `client.*` property accesses use `await`.
- **`GatewayClient`**: `connect` and `readLoop` `eventSink` parameters typed
  `@escaping @Sendable`. Soundboard event name strings corrected.
- **`ViewManager`**: `ViewHandler` typealias is now `@Sendable`.
- **`Cache`**: added background periodic eviction task (runs every 60 s) for
  entries with configured TTL. No longer requires manual `pruneIfNeeded()` calls.

### Changed — REST Layer
- **Typed throws** — all `HTTPClient` and `RateLimiter` methods now declare
  `throws(DiscordError)`. Call sites no longer need `as? DiscordError` casts.
- **`DiscordError`**: added `Sendable` conformance, `.unavailable` case (replaces
  the internal `HTTPUnavailable` struct), and doc comments on every case.
- **`RateLimiter.waitTurn(routeKey:)`**: `throws(DiscordError)`. Wraps
  `Task.sleep` `CancellationError` as `DiscordError.cancelled`.

### Changed — Types Marked Sendable
- `Box<T>` (`Message.swift`): `@unchecked Sendable`.
- `HTTPClient`: `@unchecked Sendable`.
- `VoiceClient`, `VoiceGateway`, `RTPVoiceSender`, `RTPVoiceReceiver`,
  `PipeOpusSource`, `URLSessionWebSocketAdapter`: `@unchecked Sendable`.
- `VoiceEncryptor`, `OpusFrame`, `VoiceAudioSource`, `WebSocketClient`,
  `DiscordEvent`: explicit `Sendable` conformance.

### Changed — Tests
- All test methods calling actor methods updated with `await`.
- `CooldownTests.testCooldownSetAndCheck()` made `async`.

## [1.3.1] - 2026-02-22

### Fixed
- `EventDispatcher`: corrected named argument order in `Channel()` calls — `rate_limit_per_user` now correctly precedes `available_tags` (Swift 6 strict ordering enforcement)
- `JSONValue`: added `stringValue: String?` computed property to convert scalar JSON values to `String`
- `SlashCommandRouter`: fixed `[String: String]` option map population — now uses `value?.stringValue` instead of assigning `JSONValue` directly
- `AutocompleteRouter`: fixed `focusedValue` assignment — now uses `o.value?.stringValue` instead of assigning `JSONValue?` to `String?`
- `CommandRouter`: fixed `handleIfCommand` — safely unwraps optional `message.content` before calling `.isEmpty`, `.hasPrefix`, `.dropFirst`
- `ViewManager`: added missing cases (`.label`, `.radioGroup`, `.checkboxGroup`, `.checkbox`) to `disableComponents` switch, making it exhaustive
- `SlashCommandRouterTests`: updated test to match updated `Interaction`, `ApplicationCommandData`, and `Option` types — `value` now uses `.string(...)` enum case, initializers include all new fields

## [1.3.0] - 2026-02-22

### Overview
Discord API update adding new interactive modal components (Radio Groups, Checkbox Groups, Checkboxes, and Labels), community invite management endpoints, gradient role colors, guild tags on users, voice state REST access, subscription renewal SKUs, and individual permission enforcement.

### Added — Models & Types
- **MessageComponent** — four new modal-only component types:
  - `Label` (type 21): top-level section container for modal components, carries its own label/description text
  - `RadioGroup` (type 22): single-selection option picker rendered inside a `Label`
  - `CheckboxGroup` (type 23): multi-selection picker with `min_values`/`max_values`, rendered inside a `Label`
  - `Checkbox` (type 24): boolean yes/no toggle
- **Role** — gradient role color support (`ENHANCED_ROLE_COLORS` guild feature):
  - `RoleColorStop` struct (`color: Int`, `position: Double?`)
  - `RoleColors` struct (`primary_color: Int?`, `gradient_stops: [RoleColorStop]?`)
  - `colors: RoleColors?` field on `Role`
  - `icon: String?` and `unicode_emoji: String?` fields on `Role`
- **User** — guild tag and profile fields:
  - `UserPrimaryGuild` struct (`guild_id`, `tag`, `badge`, `identity_enabled`, `identity_guild_id`)
  - `primary_guild: UserPrimaryGuild?` on `User`
  - `banner: String?`, `accent_color: Int?`, `flags: Int?`, `public_flags: Int?` on `User`
- **Invite** — community invite fields:
  - `PartialInviteRole` struct — partial role object now returned by `Get Channel Invites`
  - `role_ids: [RoleID]?` — roles automatically granted when the invite is accepted
  - `roles: [PartialInviteRole]?` — hydrated partial role objects
  - `target_type: Int?` — restricted invite target type
- **AppSubscription** — `renewal_sku_ids: [SKUID]?` field for multi-tier subscriptions

### Added — REST Endpoints
- **Roles**
  - `getGuildRole(guildId:roleId:)` — `GET /guilds/{guild.id}/roles/{role.id}` (added Discord 2025-08-12)
- **Voice States** (HTTP, no Gateway connection required)
  - `getCurrentUserVoiceState(guildId:)` — `GET /guilds/{guild.id}/voice-states/@me` (added Discord 2025-08-05)
  - `getUserVoiceState(guildId:userId:)` — `GET /guilds/{guild.id}/voice-states/{user.id}` (added Discord 2025-08-05)
- **Community Invite Target Users** (added Discord 2026-01-13)
  - `getInviteTargetUsers(code:)` — `GET /invites/{code}/users` — returns raw CSV as `Data` (decode with `String(data:encoding:)`)
  - `updateInviteTargetUsers(code:file:)` — `PATCH /invites/{code}/users` — upload CSV to replace allowed users list
  - `getInviteTargetUsersJobStatus(code:jobId:)` — `GET /invites/{code}/users/jobs/{job_id}` — poll upload job status
- `InviteTargetUsersJobStatus` result type added to `DiscordClient`

### Updated — REST Endpoints
- `modifyCurrentMember(guildId:nick:avatar:banner:bio:)` — added `avatar`, `banner`, and `bio` parameters (Discord 2025-09-10)
- `createChannelInvite` — added `roleIds: [RoleID]?` and `targetUsersFile: FileAttachment?` parameters; automatically switches to multipart when a file is provided (Discord 2026-01-13)

### Updated — Interactions
- `InteractionResponseType.launchActivity` (raw value `12`) — launch a linked Activity from an interaction response (Discord 2024-08-26)

### Breaking Changes
- `Invite.roles` type changed from `[Role]?` to `[PartialInviteRole]?` — Discord's `Get Channel Invites` now returns partial role objects without all fields (Discord breaking change 2026-02-05)

### Notes
- **Permission enforcement** (effective 2026-02-23): `PIN_MESSAGES` (bit 51), `BYPASS_SLOWMODE` (bit 52), `CREATE_GUILD_EXPRESSIONS` (bit 43), and `CREATE_EVENTS` (bit 44) are now enforced independently server-side. These bits were already present in `PermissionBitset` since v1.0.0 — no code changes required.

## [1.2.0] - 2026-02-08

### Overview
Discord API v10 update bringing SwiftDisc to feature parity with Discord as of February 2026. Adds interaction support with attachment options, polls, monetization, soundboard, onboarding, and 15 gateway events.

### Added - Models & Types
- **Interaction**
  - Resolved data maps for users, roles, channels, attachments, messages
  - `ApplicationCommandData.Option` uses `JSONValue` for string/int/number/bool/attachment options
  - `ResolvedChannel`, `ResolvedRole`, `ResolvedMember`, `ResolvedAttachment` types
  - Modal submit components, context menus, attachment command options
  - Fields: `locale`, `guild_locale`, `app_permissions`, `context`, `authorizing_integration_owners`

- **Message**
  - 30+ fields added for modern Discord payloads
  - `poll` structure with media, answers, results
  - `message_reference` and `referenced_message` for replies
  - `interaction_metadata` for tracking interaction sources
  - `flags`, `sticker_items`, `role_subscription_data`, `resolved` maps
  - `AllowedMentions` for mention control
  - Voice message metadata (waveform, duration)

- **Channel**
  - Voice/stage/forum/media channel fields
  - `ThreadMetadata` for thread properties
  - `bitrate`, `user_limit`, `rtc_region`, `video_quality_mode`, `flags`
  - Forum: `applied_tags`, `default_reaction_emoji`, `default_thread_rate_limit_per_user`
  - Media channel support

- **Monetization** (NEW)
  - `SKU` - Application SKU model
  - `Entitlement` - User/guild entitlements with subscriptions
  - `AppInstallation` - Installation tracking
  - `AppSubscription` - Subscription management
  - Snowflake types: `EntitlementID`, `AppInstallationID`, `AppSubscriptionID`

- **Onboarding** (NEW)
  - `Onboarding` - Guild onboarding configuration
  - `OnboardingPrompt` - Prompts with options
  - `OnboardingPromptOption` - Channel/role assignments

- **Permissions**
  - `useSoundboard` (bit 45)
  - `useExternalSounds` (bit 46)
  - `sendVoiceMessages` (bit 47)
  - `sendPolls` (bit 49)

### Added - Gateway Events
- **AutoMod**: `AUTO_MODERATION_RULE_CREATE/UPDATE/DELETE`, `AUTO_MODERATION_ACTION_EXECUTION`
- **Audit Log**: `GUILD_AUDIT_LOG_ENTRY_CREATE`
- **Polls**: `POLL_VOTE_ADD`, `POLL_VOTE_REMOVE`
- **Soundboard**: `SOUND_BOARD_SOUND_CREATE/UPDATE/DELETE`
- **Entitlements**: `ENTITLEMENT_CREATE/UPDATE/DELETE`

### Added - REST Endpoints
- **Messages**
  - `sendMessage` now supports `allowed_mentions`, `message_reference` (replies), `tts`, `flags`, `sticker_ids`, `attachments`, `poll`
  - `sendMessageWithFiles` with same options
  - `endPoll(channelId:messageId:pollId:)` - Close poll

- **Stickers**
  - `createGuildSticker(guildId:name:description:tags:file:)` - Upload sticker (multipart)
  - `modifyGuildSticker(guildId:stickerId:name:description:tags:)` - Update sticker
  - `deleteGuildSticker(guildId:stickerId:)` - Delete sticker

- **Soundboard**
  - `listSoundboardSounds(guildId:)` - List sounds
  - `createSoundboardSound(guildId:name:emojiId:emojiName:volume:sound:)` - Upload sound (multipart)
  - `modifySoundboardSound(guildId:soundId:name:emojiId:emojiName:volume:)` - Update sound
  - `deleteSoundboardSound(guildId:soundId:)` - Delete sound

- **Monetization**
  - `listEntitlements(applicationId:userId:guildId:before:after:limit:skuIds:)` - List entitlements
  - `createTestEntitlement(applicationId:skuId:ownerId:ownerType:)` - Create test entitlement
  - `consumeEntitlement(applicationId:entitlementId:)` - Consume entitlement
  - `listSKUs(applicationId:)` - List SKUs
  - `listApplicationInstalls(applicationId:after:limit:)` - List installs
  - `listCurrentUserInstalls(applicationId:withAppToken:)` - User installs
  - `listApplicationSubscriptions(applicationId:status:limit:before:after:)` - List subscriptions
  - `getApplicationSubscription(applicationId:subscriptionId:)` - Get subscription

- **Onboarding**
  - `getGuildOnboarding(guildId:)` - Get onboarding config
  - `updateGuildOnboarding(guildId:prompts:defaultChannelIds:enabled:mode:)` - Update onboarding

### Changed
- **Breaking**: `Interaction.ApplicationCommandData.Option.value` is now `JSONValue?` (was `String?`) to support int/bool/attachment options
- **Breaking**: `Message.content` and many fields are now optional to match Discord payloads
- Added convenience initializer to `Channel` with optional parameters
- `authorizing_integration_owners` type changed from `[String: Snowflake]` to `[String: String]`

### Fixed
- Interaction options with non-string values (int/bool/attachment) now decode correctly
- Attachment command options work via `resolved.attachments` map
- Message replies, flags, polls, and interaction metadata are accessible
- Channel fields for voice/forum/media channels exposed

### Migration
**Interaction Options**: Parse `JSONValue` instead of `String`:
```swift
if case .string(let str) = option.value {
    // handle string
} else if case .int(let num) = option.value {
    // handle integer
}
```

**Message Fields**: Many fields are now optional, use optional chaining.

## [1.1.0] - 2025-12-30

### Overview
Adds 9 gateway events, REST endpoints for webhooks/bans/invites/guild management, and fixes builder pattern issues.

### Added - Gateway Events
- `TYPING_START` - User starts typing
- `CHANNEL_PINS_UPDATE` - Channel pins updated
- `PRESENCE_UPDATE` - User presence changes
- `GUILD_BAN_ADD` - User banned
- `GUILD_BAN_REMOVE` - User unbanned
- `WEBHOOKS_UPDATE` - Webhooks updated
- `GUILD_INTEGRATIONS_UPDATE` - Guild integrations updated
- `INVITE_CREATE` - Invite created
- `INVITE_DELETE` - Invite deleted/expired

### Added - REST Endpoints
- **Ban Management**: `getBan`, `getBans`, `banMember`, `unbanMember`
- **Webhooks**: `createWebhook`, `getChannelWebhooks`, `getGuildWebhooks`, `getWebhook`, `modifyWebhook`, `deleteWebhook`, `executeWebhook`
- **Guild Management**: `deleteGuild`, `getGuildVanityURL`, `getGuildPreview`
- **Audit Logs**: `getGuildAuditLog`
- **Invites**: `getInvite`, `deleteInvite`

### Added - Models
- `GuildPreview`, `VanityURL`, `TypingStart`, `ChannelPinsUpdate`, `PresenceUpdate`, `GuildBanAdd`, `GuildBanRemove`, `WebhooksUpdate`, `GuildIntegrationsUpdate`, `InviteCreate`, `InviteDelete`

### Fixed
- Removed `mutating` keyword from builder methods - builders now return new instances
- `ViewManager` refactored for actor isolation
- Platform compatibility for URLSessionConfiguration and AsyncStream

### Removed
- Duplicate source files: `CommandFramework.swift` and `Cog.swift`

### Migration
Use `let` instead of `var` with builders:
```swift
let button = ButtonBuilder()
  .style(.primary)
  .label("Click me")
  .build()
```

## [1.0.0] - 2025-12-27

### Added
- Message pins (paginated), file uploads in modals/interactions
- Permission bits: `PIN_MESSAGES`, `BYPASS_SLOWMODE`, `CREATE_GUILD_EXPRESSIONS`, `CREATE_EVENTS`, `USE_EXTERNAL_APPS`
- Command framework: `CommandRouter`, `CommandContext`
- Cog system: `Cog` protocol, `ExtensionManager`
- Collectors: `createMessageCollector`, `streamGuildMembers`, `streamChannelPins`
- Components V2: `MessageComponent` models, fluent builders
- View Manager: persistent UI views with `custom_id` matching
- Converters for parsing mentions and IDs

### Changed
- Paginated pins API added: `streamChannelPins`, `getChannelPinsPaginated`
- Permission bits updated

## [0.12.0] - 2025-12-10

### Added
- Role connections and linked roles support
- Typed permission bitset with cache integration

## [0.10.2] - 2025-12-03

### Fixed
- Gateway connection sequence documented
- Voice gateway handshake clarified
- `ShardingGatewayManager` cache now instance-local

## [0.10.1] - 2025-11-16

### Changed
- Typed ID aliases throughout models
- Added `PartialGuild` model
- Platform guards for URLSession config
- Voice `Secretbox` buffer handling updated

## [0.10.0] - 2025-11-14

### Added
- Discord utils: mentions, emoji, timestamps, markdown
- `JSONValue` for flexible payloads
- Experimental voice support (macOS/iOS)
- Voice API: `joinVoice`, `leaveVoice`, `playVoiceOpus`

## [0.9.0] - 2025-11-13

### Added
- Thread events, scheduled events, reactions
- Raw REST endpoints
- File uploads with MIME inference
- Autocomplete support
- Caching with TTL and LRU
- Extensions via `SwiftDiscExtension`
- Permission utilities

## [0.8.0] - 2025-11-13

### Added
- Slash command builder
- Modal support with text inputs
- Message component builders
- Rich presence with activity model
- Heartbeat timing and reconnect improvements

## [0.7.0] - 2025-11-12

### Added
- Generic `Snowflake<T>` for type safety
- Reactions, threads, bulk ops, pins, file uploads
- Gateway events: message updates/deletes/reactions, guild events
- Emoji, user/bot profile, prune, roles, permission overwrites
- Interaction follow-ups

## [0.6.1] - 2025-11-12

### Added
- Per-shard presence and event streams
- Staggered connection mode
- Guild distribution verification
- Graceful shutdown and health APIs
- Resume metrics
- Stickers, forums, auto moderation, scheduled events, stage instances, audit logs

## [0.6.0] - 2025-11-11

### Added
- Slash command routing with `SlashCommandRouter`
- Full slash command management
- Gateway actor conversion
- Sharding support
- Expanded REST coverage: channels, guilds, members, roles, messages, interactions, webhooks, bans
- Rich embeds and message components
- GitHub Actions CI for macOS/Windows

## [0.5.2] - 2025-11-11

### Added
- Slash command router
- Slash bot example
- Expanded models: Channel, Guild, Message, Interaction
- Voice groundwork

## [0.5.0] - 2025-11-11

### Added
- Extended embed model
- Slash command options support
- CI for macOS and Windows

## [0.4.0] - 2025-11-11

### Added
- Embeds support
- Minimal slash commands

## [0.3.0] - 2025-11-11

### Added
- Callback adapters: `onReady`, `onMessage`, `onGuildCreate`
- Prefix command framework
- Presence update helper
- Message caching

### Changed
- Gateway resume support
- Professional README

## [0.2.0] - 2025-11-11

### Added
- Per-route rate limiting
- Retry/backoff for 429 and 5xx
- API error decoding
- Models: Guild, Interaction, Webhook
- REST endpoints: Channels, Guilds, Interactions, Webhooks

## [0.1.0] - 2025-11-11

### Added
- Gateway: Identify, Resume, Reconnect
- Heartbeat ACK tracking
- Intent support
- Events: READY, MESSAGE_CREATE, GUILD_CREATE, INTERACTION_CREATE
- Sharding and presence updates

## [0.1.0-alpha] - 2025-11-11

### Added
- Initial Swift package
- REST basics: GET/POST, JSON, rate limiter
- Models: Snowflake, User, Channel, Message
- Gateway: opcodes, intents, Identify, Heartbeat, event stream
- WebSocket abstraction
- In-memory cache
