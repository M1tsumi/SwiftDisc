# Examples — Quick Start

These examples are simple, single-file bots demonstrating new features. They assume you have a Discord bot token available as an environment variable `DISCORD_BOT_TOKEN` and a Swift toolchain installed.

## 0) Prepare
- Set your token in the shell session
  - Windows PowerShell
    ```powershell
    $env:DISCORD_BOT_TOKEN = "YOUR_BOT_TOKEN"
    ```
  - macOS/Linux bash/zsh
    ```bash
    export DISCORD_BOT_TOKEN="YOUR_BOT_TOKEN"
    ```

## 1) Autocomplete
- File: `Examples/AutocompleteBot.swift`
- What it does: Registers a `/search` command with an autocomplete provider for the `query` option and echoes the selection.
- Run (from repo root):
  - SwiftPM executable targets are provided. Example:

    ```bash
    swift run AutocompleteBotExample
    ```

    PowerShell (Windows):

    ```powershell
    swift run AutocompleteBotExample
    ```

  - Alternatively, copy into your app target or run as a script where supported.

## 2) File Uploads
- File: `Examples/FileUploadBot.swift`
- What it does: Sends a local file as an attachment with an embed. Update the `channelId` and file path before running.
- Notes: `DiscordConfiguration(maxUploadBytes:)` can override the default 100MB guardrail.

## 3) Threads & Scheduled Events Listener
- File: `Examples/ThreadsAndScheduledEventsBot.swift`
- What it does: Prints thread lifecycle and guild scheduled event activity to stdout.

## 4) Voice — Stream Opus from stdin (macOS)
- File: `Examples/VoiceStdin.swift`
- What it does: Joins a voice channel and streams length‑prefixed Opus frames from stdin using `PipeOpusSource`.
- Requirements: `DiscordConfiguration(enableVoiceExperimental: true)`; provide Opus packets (48kHz, ~20ms). No Swift dependencies required.
- Usage:
  - Build/run the example and pipe framed Opus into stdin.
  - Framing format per packet: `[u32 little‑endian length][<length> bytes]` repeated.

## Minimal Integration Snippets

### Autocomplete registration
```swift
let slash = SlashCommandRouter()
client.useSlashCommands(slash)
let ac = AutocompleteRouter()
client.useAutocomplete(ac)

ac.register(path: "search", option: "query") { ctx in
    let q = (ctx.focusedValue ?? "").lowercased()
    let results = ["Swift","Discord","NIO","Opus","Uploads","Autocomplete"]
    return results.filter { q.isEmpty || $0.lowercased().contains(q) }
                  .prefix(5)
                  .map { .init(name: $0, value: $0) }
}
```

### File upload with embed
```swift
let data = try Data(contentsOf: URL(fileURLWithPath: "./README.md"))
let attachment = FileAttachment(filename: "README.md", data: data, description: "Docs", contentType: "text/markdown")
_ = try await client.sendMessageWithFiles(channelId: "CHANNEL_ID", content: "Here is the file", embeds: [Embed(title: "Uploaded README")], files: [attachment])
```

### Threads & scheduled events logging (event stream)
```swift
for await ev in client.events {
    switch ev {
    case .threadCreate(let ch): print("thread create", ch.id)
    case .guildScheduledEventCreate(let e): print("gse create", e.name)
    default: break
    }
}
```

## Notes
- Examples are intentionally minimal; integrate them into your own executable target for `swift run` convenience.
- Ensure the bot has the needed intents and permissions in the Developer Portal.
