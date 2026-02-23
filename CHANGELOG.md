# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
