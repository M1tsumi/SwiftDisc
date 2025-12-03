## [0.11.0] - Unreleased

### Planned Highlights
- Voice receive and richer voice utilities building on the current experimental, send-only implementation.
- Performance and memory improvements for large, multi-shard bots.
- Windows platform parity work, including a dedicated WebSocket adapter where needed.
- Continued coverage for new Discord APIs (Components V2, Polls, application resources) as they evolve.

### Planned Breaking Changes
- Experimental voice APIs and configuration flags may be refined before `0.11.0` ships (names and shapes subject to change).
- Some internal helper types may be moved or renamed as part of performance and cleanup work; any user-facing breakage will be documented in the final `0.11.0` notes.

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
