# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning.

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
