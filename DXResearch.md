# DX Research Notes for v2.1.0

Date: 2026-04-11

## Sources reviewed
- discord.py docs (quickstart, intents primer, logging, migration/version pages)
- discord.js docs/guide landing pages
- twilight docs (core crate split, cache/gateway/http composition, bootstrap example)
- serenity docs (examples-first docs, module organization, shared Result/Error types)
- JDA wiki (bot setup flow, OAuth invite flow, intents, troubleshooting links)

## Common DX norms across mature wrappers
1. First-run success in under 5-10 minutes.
2. Explicit token and intents guidance early in docs.
3. Example-first onboarding with small runnable bots.
4. Clear separation between gateway, HTTP, cache, and command layers.
5. Built-in or clearly documented rate-limit and reconnect behavior.
6. Versioning and migration guidance visible from the main docs.
7. Easy help paths: FAQ, issue tracker, community server/discussions.

## What we changed in SwiftDisc
1. Rewrote README to be task-oriented and human-readable.
2. Merged installation/onboarding guidance into README and removed duplicate install guide file.
3. Centered docs on real user goals: install, run first bot, choose intents, troubleshoot.
4. Added direct links to runnable examples and support paths.

## Recommended next DX improvements
1. Add a dedicated quickstart doc with copy-paste minimal bots for message, slash command, and component flows.
2. Add an intents-and-permissions guide with practical presets by bot type.
3. Add a troubleshooting page with CI/platform-specific known issues.
4. Add a migration note from 2.0 to 2.1.
5. Add a logging guide with suggested structured logging defaults.
6. Add a small starter-template repository linked from README.

## Release positioning guidance
For v2.1.0 messaging, lead with reliability and onboarding:
- "Typed Swift Discord wrapper with practical examples and smoother first-run experience."
- "Swift 6 concurrency-safe patterns baked into examples and routers."
- "Cleaner docs and lower setup friction for new bot developers."
