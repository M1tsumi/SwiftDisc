## [1.1.0] - 2025-12-30

### Overview
Major feature release expanding SwiftDisc's Discord API coverage! This version adds 9 critical gateway events, comprehensive REST endpoint coverage for webhooks, bans, invites, and guild management, plus critical builder pattern fixes. SwiftDisc provides extensive coverage of Discord's core features with intuitive APIs and strong performance.

### Added - Gateway Events 🎉
- **Complete Gateway Event Coverage**: Added 9 critical missing gateway events for full Discord API parity
  - `TYPING_START` - Fired when a user starts typing in a channel
  - `CHANNEL_PINS_UPDATE` - Fired when channel pins are updated
  - `PRESENCE_UPDATE` - Fired when a user's presence (online/offline/dnd/idle) changes
  - `GUILD_BAN_ADD` - Fired when a user is banned from a guild
  - `GUILD_BAN_REMOVE` - Fired when a user is unbanned from a guild
  - `WEBHOOKS_UPDATE` - Fired when webhooks in a channel are updated
  - `GUILD_INTEGRATIONS_UPDATE` - Fired when guild integrations are updated
  - `INVITE_CREATE` - Fired when an invite is created
  - `INVITE_DELETE` - Fired when an invite is deleted or expires
- All events include comprehensive typed models with proper Codable conformance
- Events are seamlessly integrated into the existing `DiscordEvent` enum and event stream

### Added - REST Endpoints 🚀
- **Ban Management** (Complete CRUD)
  - `getBan(guildId:userId:)` - Get a specific ban
  - `getBans(guildId:limit:before:after:)` - List all bans with pagination
  - `banMember(guildId:userId:deleteMessageDays:reason:)` - Ban a member with message history cleanup
  - `unbanMember(guildId:userId:)` - Unban a member

- **Webhooks** (Complete CRUD + Execution)
  - `createWebhook(channelId:name:avatar:)` - Create a webhook in a channel
  - `getChannelWebhooks(channelId:)` - Get all webhooks for a channel
  - `getGuildWebhooks(guildId:)` - Get all webhooks for a guild  
  - `getWebhook(webhookId:)` - Get a specific webhook
  - `modifyWebhook(webhookId:name:avatar:channelId:)` - Update webhook properties
  - `deleteWebhook(webhookId:)` - Delete a webhook
  - `executeWebhook(webhookId:token:content:username:avatarUrl:embeds:wait:)` - Execute webhook with rich options

- **Guild Management**
  - `deleteGuild(guildId:)` - Delete a guild (owner only)
  - `getGuildVanityURL(guildId:)` - Get guild's vanity URL code and usage count
  - `getGuildPreview(guildId:)` - Get public guild preview (for discovery)

- **Audit Logs**
  - `getGuildAuditLog(guildId:userId:actionType:before:limit:)` - Fetch guild audit log entries with comprehensive filtering

- **Invites**
  - `getInvite(code:withCounts:withExpiration:)` - Get invite details with member counts
  - `deleteInvite(code:)` - Delete/revoke an invite

### Added - Models
- **New Model Types** for complete API coverage:
  - `GuildPreview` - Public guild information for guild discovery
  - `VanityURL` - Guild vanity URL with usage statistics
  - `TypingStart` - Typing indicator event data
  - `ChannelPinsUpdate` - Channel pin update event data
  - `PresenceUpdate` - User presence change event with rich client status
  - `GuildBanAdd/GuildBanRemove` - Ban event data with user information
  - `WebhooksUpdate` - Webhook update event for a channel
  - `GuildIntegrationsUpdate` - Guild integration update event
  - `InviteCreate/InviteDelete` - Full invite lifecycle event data with metadata

### Fixed
- **Builder Pattern API**: Removed incorrect `mutating` keyword from builder methods in `ComponentsBuilder`, `EmbedBuilder`, `ButtonBuilder`, `SelectMenuBuilder`, `TextInputBuilder`, and `ActionRowBuilder` to properly support fluent method chaining on all platforms
  - Builders now correctly return new instances without requiring variable mutation
  - Fixes issue where chained builder methods would fail to compile on macOS
- **ViewManager**: Refactored to resolve actor isolation issues and ensure thread-safe operation
  - Fixed `start(client:)` method to properly handle actor isolation with `nonisolated` keyword
  - Removed duplicate method definitions that caused build conflicts
  - Added proper task management with `setListeningTask(_:)` helper
- **Platform Compatibility**: Enhanced cross-platform build support
  - Added proper platform guards for URLSessionConfiguration properties
  - Fixed AsyncStream usage patterns for Swift 5.9+ compatibility
  - Improved Windows build compatibility

### Removed
- **Duplicate Source Files**: Cleaned up codebase by removing duplicate and conflicting files
  - Removed `Sources/SwiftDisc/HighLevel/CommandFramework.swift` (duplicate of `CommandRouter.swift`)
  - Removed `Sources/SwiftDisc/HighLevel/Cog.swift` (functionality consolidated)
  - Retained canonical implementations in `CommandRouter.swift` with proper organization

### Changed
- **Test Suite**: Updated tests to reflect builder pattern changes and new API signatures
  - Updated `ComponentsV2Tests` to use non-mutating builder pattern
  - Updated `SlashCommandRouterTests` with required parameters
  - Adjusted `ViewManagerTests` for actor isolation changes

### Performance & Developer Experience
- **Fully Typed APIs**: All new endpoints use strongly-typed IDs (`UserID`, `GuildID`, `ChannelID`, `WebhookID`, etc.) for compile-time safety
- **Async/Await Throughout**: All new endpoints are fully async/await compatible for modern Swift concurrency
- **Zero Dependencies**: All features implemented using pure Swift with no external dependencies
- **Production Ready**: SwiftDisc now covers the essential Discord API features needed for most bot use cases

### API Coverage Highlights
- ✅ **Gateway Events**: 47 event types covering core Discord actions (messages, guilds, channels, members, roles, reactions, threads, scheduled events, interactions, voice, typing, presence, bans, webhooks, invites)
- ✅ **REST Endpoints**: 100+ typed methods for common bot operations
- ✅ **Core Features**: Messages, embeds, components, slash commands, webhooks, channels, guilds, members, roles
- ✅ **Advanced Features**: Audit logs, bans, invites, polls, threads, scheduled events, stage instances, auto-moderation, voice
- ℹ️ **Note**: Some Discord API endpoints are not yet wrapped (e.g., guild sticker CRUD, soundboard). Use `rawGET`, `rawPOST`, etc. for unwrapped endpoints.

### Migration Notes
- **Builder Pattern**: If you were previously using `var` declarations with builder methods, you can now use `let` declarations since builders are no longer mutating
  ```swift
  // Before (v1.0.0):
  var builder = ButtonBuilder()
  builder = builder.style(.primary)
  builder = builder.label("Click me")
  
  // After (v1.1.0) - Both patterns work, but immutable is preferred:
  let button = ButtonBuilder()
    .style(.primary)
    .label("Click me")
    .build()
  ```

- **New Gateway Events**: To handle new events, add handlers to your event loop:
  ```swift
  for await event in client.events {
      switch event {
      case .typingStart(let typing):
          print("\(typing.user_id) is typing in \(typing.channel_id)")
      case .presenceUpdate(let presence):
          print("\(presence.user.id) is now \(presence.status)")
      case .guildBanAdd(let ban):
          print("\(ban.user.username) was banned from \(ban.guild_id)")
      // ... handle other events
      default: break
      }
  }
  ```

### Breaking Changes
None - all changes are additive and backward compatible!

## [1.0.0] - 2025-12-27

### Overview
- Stable v1.0.0 release: broad REST and Gateway coverage, permission parity with platform changes, Components V2 + modal file upload support, and performance/optimization work to prepare for production-scale bots.

### Major Additions

- Expanded endpoint coverage and convenience wrappers for message pins (paginated), per-attachment-aware file uploads in modals and interaction follow-ups, and the Get Guild Role Member Counts endpoint.
- Permission bits added for recent platform splits: `PIN_MESSAGES`, `BYPASS_SLOWMODE`, `CREATE_GUILD_EXPRESSIONS`, `CREATE_EVENTS`, `USE_EXTERNAL_APPS`.
- Added a lightweight Command Framework: `CommandRouter` and `CommandContext` for quick prefix-based command handling. See `Sources/SwiftDisc/HighLevel/CommandFramework.swift` and `Examples/CommandFrameworkBot.swift`.
- Minimal Cog/Extension system: `Cog` protocol and `ExtensionManager` to modularize bot features. See `Sources/SwiftDisc/HighLevel/Cog.swift` and `Examples/CogExample.swift`.
- Initial collectors and paginator helpers: AsyncStream-based paginators to help iterate large result-sets (pins, members) without manual paging boilerplate.
 - Initial collectors and paginator helpers: `createMessageCollector` (AsyncStream-based message collector), `streamGuildMembers` paginator, and `streamChannelPins` for pin streaming. These helpers reduce pagination and event-filtering boilerplate and integrate with the client's event stream.

- Components V2: full typed integration with `MessageComponent` models, fluent builders (`ButtonBuilder`, `SelectMenuBuilder`, `TextInputBuilder`, `ActionRowBuilder`, `ComponentsBuilder`), and an `EmbedBuilder` for rich messages. Added `Examples/ComponentsExample.swift` and serialization smoke-tests to verify output. These builders are intended for direct use with `DiscordClient.sendMessage(..., components: [MessageComponent])` and interaction payloads.

- View Manager: added a concurrency-safe `ViewManager` for persistent UI views, prefix or exact `custom_id` matching, automatic expiration, and a simple integration via `client.useViewManager(_:)`. See `Sources/SwiftDisc/HighLevel/ViewManager.swift` and `Examples/ViewExample.swift`.
- Developer experience improvements: example scaffolds, a small smoke-test suite for new features, and expanded README documentation describing the new command framework and examples.

### Developer Experience & Command Framework

- Added a lightweight, extensible command framework to accelerate common bot workflows: `CommandRouter`, `CommandContext`, async `Check` predicates, and per-command cooldowns with `user`, `guild`, and `global` scopes. This is intentionally small and composable so projects may layer richer frameworks on top.
- Converters: small helpers to parse common argument formats (mentions and plain IDs) into typed `Snowflake<T>` aliases (`UserID`, `ChannelID`, `RoleID`), reducing parsing boilerplate in commands.
- Cogs / Extensions: a minimal `Cog` protocol and `ExtensionManager` to group related handlers and lifecycle hooks for modular bots and plugins.
- Tests & Examples: added example bots demonstrating command routing and cogs, plus basic smoke tests for converters, cooldowns, and the cog loader to improve confidence in CI.

These additions were added to improve developer ergonomics and to provide a stable foundation for larger, higher-level command/extension frameworks (e.g., converters, decorators, persistent views, collectors).

### Performance & Stability
- Rate-limiter and `HTTPClient` improvements for robustness under burst operations, and guidance for respecting gateway limits (e.g., Request Guild Members 1 request/guild/30s).
- Sharding & health collection improvements (concurrent sampling, less logging noise) and memory/perf guards for large bots.

### Migration Notes
- This is a major release (v1.0.0) but efforts were made to preserve existing public APIs; deprecated endpoints (old pin routes) are still available via compatibility helpers but new V2 helpers are recommended.

### Breaking Changes
- `getPinnedMessages(channelId:)` was previously the primary pins helper. For v1.0.0 the library introduces paginated pins endpoints and a streaming helper `streamChannelPins(channelId:pageLimit:)`. While the old `getPinnedMessages` is still available for compatibility, prefer the paginated API for reliability in large channels — callers that rely on exact ordering should migrate to `streamChannelPins` or `getChannelPinsPaginated`.
- Permission bit names: several new flags were added to `PermissionBitset` and `PermissionsUtil` behavior expects you to request specific new permission bits for pinning, bypassing slowmode, creating events and expressions. Callers that previously assumed `MANAGE_MESSAGES` or `MANAGE_EVENTS` would grant these abilities must update their requested permissions.

### Migration Guidance
- Pins: replace `getPinnedMessages(channelId:)` uses where you need paginated results with `streamChannelPins(channelId:pageLimit:)` for streaming consumption or `getChannelPinsPaginated(channelId:limit:after:)` for explicit paging.
- Permissions: add the new flags to your install scopes / permission requests: `pinMessages`, `bypassSlowmode`, `createGuildExpressions`, `createEvents`, `useExternalApps` (see `Models/PermissionBitset.swift`).
- File uploads in modals: use the new `createInteractionResponseWithFiles` and `createFollowupMessageWithFiles` helpers; check `DiscordConfiguration.maxUploadBytes` to confirm allowed per-attachment sizes.




## [0.10.2] - 2025-12-03

### Highlights
- Build and CI polish for newer Swift toolchains (including Swift 6) and Windows runners.
- No public API or wire-format changes; this is a non-breaking patch release focused on build stability and compatibility.

### Fixed
- Gateway
  - Clarified and documented the connection sequence in `GatewayClient` (HELLO, heartbeat start, Resume/Identify, read loop, READY/RESUMED) to make the flow easier to reason about and debug.
- Voice
  - Clarified the voice gateway handshake steps in `VoiceGateway` (HELLO, Identify, READY, protocol select, SessionDescription) to better reflect the actual runtime behavior.
- Sharding
  - Updated `ShardingGatewayManager`’s `cachedGatewayBot` cache to be instance-local instead of a static property, resolving potential actor-isolation/build issues on newer Swift toolchains while preserving 24‑hour caching semantics.

### Docs & CI
- CI
  - Updated GitHub Actions workflows to use a newer Swift toolchain on Windows (Swift 6.2) and tightened Windows build server configuration.
  - Iterated on CI configuration to reduce flaky failures and keep the matrix aligned with current project requirements.
  
## [0.10.1] - 2025-11-16

### Highlights
- Cross-platform polish: verified builds and tests on macOS and Windows, aligned tests with current APIs, and tightened platform guards.

### Changed
- Models
  - Completed migration away from bare `Snowflake` usages to typed ID aliases in remaining models (webhooks, stickers, invites, audit log, auto-moderation, stage instances, scheduled events).
  - Added `PartialGuild` model used by `getCurrentUserGuilds`.
- REST / HTTP
  - Updated `HTTPClient` to import `FoundationNetworking` where available and gate URLSession configuration (e.g. `waitsForConnectivity`) behind platform checks.
  - Ensured actor-isolated `RateLimiter` methods are called with `await` from HTTP helpers.
  - Added explicit typed ID parameters (e.g. `GuildID`, `ChannelID`, `ApplicationCommandID`, `StickerID`, `WebhookID`, `AutoModerationRuleID`, `AuditLogEntryID`) to remaining REST helpers.
- Voice / Crypto
  - Refactored `Secretbox` Salsa20 core to avoid overlapping inout accesses and use explicit buffer handling in `withUnsafeBytes`.
- Tests
  - Updated `SlashCommandRouterTests` to use the new `focused` field on interaction options.
  - Updated `ShardingTests` to construct `Guild` with the new initializer signature and to assert optional shard latency safely.

### Docs & CI
- README
  - Documented the Build & Test flow for macOS/Linux and Windows (`swift build` / `swift test`) and noted the CI environments.
  - Clarified Windows row in the Platform Requirements table (Swift 5.9+; CI on Windows Server 2022 + Swift 5.10.1).
- CI
  - Confirmed `.github/workflows/ci.yml` builds and tests on `macos-latest` (Xcode 16.4) and `windows-2022` (Swift 5.10.1), matching the local configuration.

## [0.10.0] - 2025-11-14

### Highlights
- Developer Discord Utils: mentions, emoji helpers, timestamps, markdown escaping.
- Experimental Voice (macOS/iOS): connect flow, UDP IP discovery, protocol select, Session Description, speaking.
- Zero-dependency encryption: pure-Swift Secretbox (XSalsa20-Poly1305) and RTP sender.
- Music-bot friendly: Opus-in pipeline with `VoiceAudioSource` and `PipeOpusSource` for stdin piping on macOS.
 - Components V2 & Polls scaffolding: generic JSON and typed envelopes to use latest Discord features now.

### Added
- Internal
  - `Internal/DiscordUtils.swift`: `Mentions`, `EmojiUtils`, `DiscordTimestamp`, `MessageFormat`.
  - `Internal/JSONValue.swift`: lightweight `JSONValue` for flexible payload composition (Components V2, Polls, future APIs).
- Voice
  - `DiscordConfiguration.enableVoiceExperimental` feature flag.
  - Voice Gateway handshake and UDP IP discovery (Network.framework).
  - `VoiceGateway`, `VoiceClient`, `VoiceSender` (RTP), `Secretbox` (XSalsa20-Poly1305), `AudioSource` protocol, `PipeOpusSource`.
  - Public API on `DiscordClient`: `joinVoice`, `leaveVoice`, `playVoiceOpus`, `play(source:)`.
- Examples
  - `Examples/VoiceStdin.swift`: stream framed Opus from stdin to a voice channel.
 - Models
   - `Models/AdvancedMessagePayloads.swift`: `V2MessagePayload`, `PollPayload` typed envelopes.
 - REST
   - Components V2 helpers: `postMessage(channelId:payload:)` (generic), `sendComponentsV2Message(channelId:payload:)` (typed envelope).
   - Poll helpers: `createPollMessage(channelId:content:poll:...)` (generic) and overload `createPollMessage(channelId:payload:...)` (typed envelope).
   - Localization: `setCommandLocalizations(applicationId:commandId:nameLocalizations:descriptionLocalizations:)`.
   - Forwarding: `forwardMessageByReference(targetChannelId:sourceChannelId:messageId:)` (portable forward using message reference).
   - Application-scoped resources: `post/patch/deleteApplicationResource(...)` generic helpers.
   - App Emoji wrappers: `createAppEmoji(...)`, `updateAppEmoji(...)`, `deleteAppEmoji(...)` (typed top-level, flexible internals).
   - UserApps wrappers: `createUserAppResource(...)`, `updateUserAppResource(...)`, `deleteUserAppResource(...)`.

### Changed
- README: expanded Voice section (usage, requirements, macOS ffmpeg piping, iOS guidance) and Developer Utilities section.
- README: added Components V2 (generic + typed envelope) examples.
- README: added Polls (generic + typed envelope) examples.
- README: added Localization and Forwarding usage.
- README: added Generic Application Resources, App Emoji, and UserApps usage.
- `advaithpr.ts`: updated feature matrix (Components V2, Polls, Localization, Forwarding, App Emoji, UserApps -> Yes).

### Notes
- Voice is send-only; input must be Opus packets (48kHz, ~20ms). No external dependencies were added.
- iOS cannot spawn ffmpeg; provide Opus from your app/backend.

## [0.9.0] - 2025-11-13

### Highlights
- 100% gateway event visibility with explicit thread/scheduled-event handling plus a raw fallback event.
- REST coverage boosted with raw passthrough helpers (`rawGET/POST/PATCH/PUT/DELETE`).
- File uploads polished: content-type detection and configurable size guardrails.
- Autocomplete implemented end-to-end with `AutocompleteRouter` and response helper.
- Advanced caching (TTL + per-channel LRU), minimal extensions/cogs, and permissions utilities.

### Added
- Gateway
  - THREAD_CREATE/UPDATE/DELETE, THREAD_MEMBER_UPDATE, THREAD_MEMBERS_UPDATE
  - GUILD_SCHEDULED_EVENT_{CREATE,UPDATE,DELETE,USER_ADD,USER_REMOVE}
  - Catch-all `DiscordEvent.raw(String, Data)` with fallback dispatch in `GatewayClient`.
- REST
  - `DiscordClient.rawGET/POST/PATCH/PUT/DELETE` for unwrapped endpoints.
- Uploads
  - `FileAttachment.contentType` and MIME inference from filename.
  - Guardrail via `DiscordConfiguration.maxUploadBytes` (default 100MB) with validation error.
- Interactions
  - `InteractionResponseType.autocompleteResult (=8)` and `createAutocompleteResponse(...)`.
  - `AutocompleteRouter` and wiring in `EventDispatcher`.
- Caching
  - `Cache.Configuration` TTLs and message LRU; `removeMessage(id:)`, typed getters, pruning.
- Extensions
  - `SwiftDiscExtension` protocol and `Cog` helper; `DiscordClient.loadExtension(_:)`, `unloadExtensions()`.
- Permissions
  - `PermissionsUtil.effectivePermissions(...)`; `PermissionOverwrite` added to `Channel`.
- Examples
  - `Examples/AutocompleteBot.swift`, `Examples/FileUploadBot.swift`, `Examples/ThreadsAndScheduledEventsBot.swift`, and `Examples/README.md`.

### Changed
- README updated to document new features, examples, and env var `DISCORD_BOT_TOKEN`.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning.

## [0.8.0] - 2025-11-13

### Highlights
- Enhanced developer UX for interactions: fluent Slash Command builder, Modal support with Text Inputs, and Message Component builders.
- Rich Presence upgrade: full activity model including buttons, with simple `setStatus` and `setActivity` helpers.
- Reliability: confirmed heartbeat timing and reconnect logic per Discord guidance (jitter, ACK check-before-send, indefinite backoff).

### Added
- Slash Commands
  - `SlashCommandBuilder` with option helpers (string/integer/number/boolean/user/channel/role/mentionable/attachment) and choices.
  - End-to-end REST support for application commands: list/create/delete, bulk overwrite (global and guild).
- Interactions: Modals
  - `InteractionResponseType.modal (=9)` and `DiscordClient.createInteractionModal(...)` helper.
  - `MessageComponent.textInput` (type 4) with `TextInput.Style` and validation helpers.
- Message Components
  - Fluent builders: `ComponentsBuilder`, `ActionRowBuilder`, `ButtonBuilder`, `SelectMenuBuilder`, `TextInputBuilder`.
- Presence
  - Expanded `PresenceUpdatePayload.Activity` with `state`, `details`, `timestamps`, `assets`, `party`, `secrets`, and `buttons`.
  - `ActivityBuilder` for composing rich activities, plus `setStatus(_:)` and `setActivity(...)` helpers.

### Fixed
- Gateway heartbeat loop sends before sleeping and includes initial jitter.
- Reconnect attempts are retried indefinitely with exponential backoff (capped) while allowed.



## [0.7.0] - 2025-11-12

### Highlights
- Full switch to generic `Snowflake<T>` for compile-time ID safety across core models and APIs.
- Major REST coverage additions: reactions, threads, bulk ops, pins, file uploads, emojis, user/bot profile, prune, roles, permission overwrites, interaction follow-ups.
- Gateway event coverage expanded: message updates/deletes/reactions and comprehensive guild events.

### Added
- Models
  - Generic `Snowflake<T>` and typed aliases: `UserID`, `ChannelID`, `MessageID`, `GuildID`, `RoleID`, `EmojiID`, `ApplicationID`, `AttachmentID`, `OverwriteID`, `InteractionID`, `ApplicationCommandID`.
  - Reaction models: `Reaction`, `PartialEmoji`.
  - Thread models: `ThreadMember`, `ThreadListResponse`.
- REST Endpoints
  - Reactions: add/remove (self/user), get, remove-all, remove-all-for-emoji.
  - Threads: start from message / without message, join/leave, add/remove/get/list members, list active/public/private/joined archived threads.
  - Bulk Ops: bulk delete messages, crosspost message.
  - Pins: get/pin/unpin.
  - File uploads: `sendMessageWithFiles`, `editMessageWithFiles` with multipart/form-data.
  - Emojis: list/get/create/modify/delete.
  - User/Bot: get user, modify current user, list current user guilds, leave guild, create DM/group DM.
  - Prune: `getGuildPruneCount`, `beginGuildPrune`, `pruneGuild(guildId:payload:)` with typed payload/response.
  - Roles: list/create/modify/delete via `RoleCreate`/`RoleUpdate`; bulk role positions (typed IDs).
  - Permission overwrites: edit/delete (typed `OverwriteID`).
  - Interaction follow-ups: get/edit/delete original; create/get/edit/delete followups.
- Gateway
  - Message: `MESSAGE_UPDATE`, `MESSAGE_DELETE`, `MESSAGE_DELETE_BULK`, reaction add/remove/remove_all/remove_emoji.
  - Guild: member add/remove/update, role create/update/delete, emojis update, stickers update, members chunk.
  - Request members (op 8) typed sender.
- HTTP
  - Multipart helpers: `postMultipart`, `patchMultipart`, `payload_json` + `files[n]` wiring.
  - Convenience no-body `put(path:)` and `delete(path:)` (204).
- Docs
  - README: version bump to 0.7.0, prominent Discord CTA button, install snippet update.

### Changed
- Migrated core models (`User`, `Guild`, `Channel`, `Message`, `GuildMember`, `Emoji`, `Interaction`) and `DiscordClient`/Gateway models to use typed Snowflakes.
- Refactored REST method signatures to typed IDs for compile-time safety.

### Notes
- Remaining auxiliary models will be migrated to typed IDs in follow-up PRs as needed.
- `permissions` fields remain `String?` for compatibility; a typed bitset may be introduced later.

## [0.6.1] - 2025-11-12

### Highlights
- ShardingGatewayManager Phase 2 complete: per-shard presence, event streams, staggered connects, guild distribution verification.
- Phase 2 Day 4: graceful shutdown and resume metrics, plus health APIs and docs.

### Added
- ShardingGatewayManager
  - Per-shard presence via configuration callbacks with fallback.
  - Per-shard filtered event streams: `events(for:)`, `events(for: [Int])`.
  - Staggered connection mode with batch pacing respecting identify concurrency.
  - Guild distribution verification after all shards READY.
  - Graceful shutdown: `disconnect()` sets shutdown gate, prevents reconnects, closes shards concurrently, clears `/gateway/bot` cache.
  - Health surfaces: `healthCheck()` aggregate metrics and `shardHealth(id:)` snapshots including resume metrics.
  - Restart API: `restartShard(_:)`.
- GatewayClient
  - Resume metrics: success/failure counters, last attempt/success timestamps.
  - `RESUMED` handling and `INVALID_SESSION` fallback with gated reconnects.
  - Reconnect gating via `setAllowReconnect(_:)`.
- REST Endpoints
  - Stickers: `getSticker`, `listStickerPacks`, `listGuildStickers`, `getGuildSticker`.
  - Forum helper: `createForumThread(...)`.
  - Auto Moderation: list/get/create/modify/delete rules.
  - Scheduled Events: list/create/get/modify/delete and list interested users.
  - Stage Instances: create/get/modify/delete.
  - Audit Logs: `getGuildAuditLog(...)`.
  - Invites & Templates: create/list/delete and template CRUD/list/sync.
- Docs
  - README: Setup & Configuration (Windows notes, env vars, intents, logging), Sharding section, Advanced Features, Production sharding config, Health Monitoring, Graceful Shutdown.
  - Tests
    - Initial sharding tests: configuration defaults, staggered delay, shard formula, ShardedEvent wrapper.

### Changed
- ShardingGatewayManager initializer split configuration concerns:
  - `init(token:configuration:intents:httpConfiguration:)` where `configuration` is sharding options and `httpConfiguration` is HTTP/Gateway config.
- README examples updated to match API and new initializer defaults.

### Fixed
- Prevent reconnect loops during shutdown by gating reconnect attempts.
- Handle `INVALID_SESSION` by clearing session/seq and performing clean re-identify.
- Track `RESUMED` to mark READY and record metrics.

### Notes
- Voice/multipart sticker upload remain deferred.

## [0.6.0] - 2025-11-11

### Highlights
- Minreqs readiness: broad REST coverage (minus voice), advanced gateway (resume/reconnect), robust rate limiting, professional README/docs, examples, and CI.

### Added
- Slash Commands
  - Typed routing via `SlashCommandRouter` with subcommand path resolution and typed accessors (string/int/bool/double).
  - Full management: create/list/delete/bulk-overwrite for global and guild commands.
  - Options: all official types and `choices` support.
  - Permissions: `default_member_permissions`, `dm_permission` via `ApplicationCommandCreate`.
- Gateway & Stability
  - `GatewayClient` converted to an actor; serialized event handling via `EventDispatcher` actor.
  - Reconnect with exponential backoff; preserve shard across reconnects; non-fatal decode errors.
- Sharding
  - `loginAndConnectSharded(index:total:)` and `ShardManager` to orchestrate multiple shards.
- REST Coverage
  - Channels: get/modify/name edit, create/delete, list messages, permissions edit/delete, bulk channel positions, typing indicator.
  - Guilds: get/modify settings (verification, notifications, system channel, content filter), widget get/modify, prune count/begin, list channels.
  - Members: get/list/modify (nick, roles).
  - Roles: list/create/modify/delete, bulk role positions.
  - Messages: send/edit (content/embeds/components), get, list.
  - Interactions: responses with content or embeds; generic response type enum.
  - Webhooks: create/execute/list/get/modify/delete.
  - Bans: list/create/delete.
- Models
  - Rich `Embed` (author/footer icon/thumbnail/image/timestamp/fields).
  - `Message` includes `embeds`, `attachments`, `mentions`, `components`.
  - `MessageComponent` (ActionRow, Button, SelectMenu).
  - `Interaction` includes guild_id and nested command options with types.
  - `Guild`, `Channel`, `GuildMember`, `Role`, `Webhook`, `GuildBan`, `GuildWidgetSettings` expanded.
- Cross-Platform & CI
  - Unified URLSession-based WebSocket adapter; tuned URLSession config.
  - GitHub Actions CI for macOS and Windows; code coverage artifact and README badge.
- High-Level API & Utilities
  - `CommandRouter` and `SlashCommandRouter` with `onError` callbacks.
  - `BotUtils`: message chunking, mention/prefix helpers.
- Docs & Examples
  - README: minreqs checklist, Distinct Value section, Production Deployment section, polished header/buttons.
  - Examples: Ping, Prefix Commands, Slash bot.

### Changed
- Rate limiter: fixed bucket reset handling; rely on response headers post-reset.
- REST/HTTP: improved headers and robustness; retries/backoff tuned.
- Event processing: moved to actor for serial handling; simplified client sinks.

### Removed
- Phase 5 roadmap (testing/benchmarks) from README per project direction; Production Deployment section added instead.

### Notes
- Voice is optional and not required for listing; future work may add voice gateway/UDP/audio.

## [0.5.2] - 2025-11-11

### Added
- SlashCommandRouter to map INTERACTION_CREATE application commands to typed handlers.
- Example: Slash commands bot (Examples/SlashBot.swift).
- Models expanded:
  - Channel: topic, nsfw, position, parent_id.
  - Guild: owner_id, member_count.
  - Message: embeds[]
  - Interaction: guild_id and ApplicationCommandData (name/options)
- Voice groundwork: VoiceState and VoiceServerUpdate models and events.

### Changed
- DiscordClient: wired slash router in both unsharded and sharded paths.
- Gateway/HTTP clients: tuned URLSession configuration for platform excellence.

### Notes
- Next: typed slash responders (subcommands, choices, permissions), voice UDP/audio, broader model/endpoint coverage.

## [0.5.0] - 2025-11-11

### Added
- Embeds: extended model (author, footer icon, thumbnail, image, timestamp, fields).
- Slash commands: options support; list/delete; bulk overwrite (global and guild).
- CI: macOS and Windows build/test workflow.

### Changed
- Gateway: unified URLSession WebSocket adapter across platforms (Windows path enabled).
- README: bumped to 0.5.0; expanded embeds details; documented full slash command management; Phase 4 core items updated.

### Notes
- Platform-specific optimizations remain pending.

## [0.4.0] - 2025-11-11

### Added
- Embeds support:
  - Send messages with embeds.
  - Send interaction responses with embeds (type 4 ChannelMessageWithSource).
- Minimal Slash Commands:
  - Create global and guild application commands.
  - Continue to handle interactions via existing gateway path.

### Changed
- README: Bumped to 0.4.0; documented embeds and minimal slash command creation.

### Notes
- Full slash command option schemas and typed responders are planned.
- Voice features remain pending.

## [0.3.0] - 2025-11-11

### Added
- Phase 3 high-level API foundations:
  - Callback adapters on `DiscordClient` (`onReady`, `onMessage`, `onGuildCreate`).
  - Minimal prefix command framework (`CommandRouter`) with registration and argument parsing.
  - Presence update helper bridging to Gateway presence op.
  - Intelligent caching start: bounded recent messages per channel in `Cache`.

### Changed
- Gateway: Implemented resume when `session_id` and `seq` are present; reconnect on opcode 7 and network errors.
- README: Professionalized header with buttons and badges. Roadmap updated to reflect Phase 3 progress. Version bumped to 0.3.0.
- Docs: Expanded high-level API section to include callbacks, commands, caching, and presence.

### Notes
- Slash commands support is planned; prefix commands shipped first for early adopters.

## [0.2.0] - 2025-11-11

### Added
- REST Phase 2 maturity:
  - Per-route rate limiting with automatic retries and global limit handling.
  - Retry/backoff for 429 and 5xx, with exponential backoff.
  - Detailed API error decoding (message/code) and improved HTTP error reporting.
  - New models: Guild, Interaction, Webhook.
  - Initial endpoint coverage: Channels, Guilds, Interactions, Webhooks.
- DiscordClient: Convenience REST methods for channels (get/modify, delete message), guild (get), interactions (create response), webhooks (create/execute).

### Changed
- README: Bumped version to 0.2.0 and marked Phase 2 roadmap items complete with REST details.
- Developer docs: Expanded REST section for per-route buckets, error decoding, endpoints.
- Install guide: Updated SPM version references to 0.2.0.

### Notes
- Additional REST endpoints will continue to be added; report priorities via Issues.

## [0.1.0] - 2025-11-11

### Added
- Gateway Phase 1 completion: Identify, Resume, and Reconnect logic.
- Heartbeat ACK tracking with jitter and improved backoff.
- Comprehensive intent support with clarified docs.
- Priority event coverage: READY, MESSAGE_CREATE, GUILD_CREATE, INTERACTION_CREATE.
- Initial sharding support and presence updates.

### Changed
- README updated to reflect 0.1.0 release, Phase 1 completion, and gateway notes.
- Developer docs updated to include resume/reconnect and expanded event coverage.

### Notes
- Windows WebSocket adapter remains planned if Foundation’s WebSocket is unavailable.

## [0.1.0-alpha] - 2025-11-11

### Added
- Initial Swift package scaffold with cross-platform targets (iOS, macOS, tvOS, watchOS, Windows intent).
- REST: Basic GET/POST, JSON encoding/decoding, simple rate limiter, error types.
- Models: Snowflake, User, Channel, Message.
- Gateway: Opcodes/models, intents, Identify/Heartbeat scaffolding, READY and MESSAGE_CREATE handling, AsyncSequence event stream.
- WebSocket abstraction with URLSession adapter and Windows placeholder.
- README with Quick Start, intents notes, roadmap, and reference to discord.py.
- .gitignore and SwiftDiscDocs.txt developer documentation.
- InstallGuide.txt with step-by-step installation and usage.
- Minimal in-memory cache wired to events (users/channels/guilds).
- Additional events: GUILD_CREATE, CHANNEL_CREATE/UPDATE/DELETE, INTERACTION_CREATE.
- Heartbeat ACK tracking with basic reconnect/backoff.

### Notes
- Windows WebSocket adapter to be implemented if Foundation’s WebSocket is unavailable.

## [0.12.0] - 2025-12-10

### Added
- Comprehensive support for Discord's role connections and linked roles, making it simpler to handle user metadata and automate role assignments for a more engaging bot experience.
- A typed permission bitset with seamless cache integration, which boosts performance by minimizing API calls and makes permission management more intuitive and error-resistant.

### Changed
- README: Documented the new features and improvements in the 0.12.0 release.
- Developer docs: Expanded permission section to include typed permission bitset and cache-integrated permission checks.

### Notes
- The new features and improvements in this release enhance the overall usability and performance of the library, making it easier for developers to build and manage their Discord bots.
