# Testing Guide for SwiftDisc v0.13.0

This guide provides comprehensive testing commands and verification instructions for the SwiftDisc library.

## 🚀 Quick Testing Commands

### Prerequisites
- Swift 5.9+ installed
- Discord bot token ready
- Git for version control

### 1. Create Testing Branch

```bash
# Create and switch to testing branch
git checkout -b feature/v0.13.0-testing

# Verify current branch
git branch

# Check status
git status
```

### 2. Build Verification

```bash
# Clean build
swift build --clean

# Standard build
swift build

# Release build
swift build -c release

# Build with verbose output
swift build --verbose
```

### 3. Run Tests

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test
swift test --filter testName

# Run tests with release configuration
swift test -c release
```

### 4. Code Quality Checks

```bash
# Format code (if using swift-format)
swift-format .

# Lint code (if using swiftlint)
swiftlint

# Check for compilation errors
swift build -Xswiftc -warn-long-function-bodies=100
```

## 🧪 Functional Testing

### 1. Basic Bot Test

Create a test bot file `TestBot.swift`:

```swift
import SwiftDisc
import Foundation

@main
struct TestBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)
        
        do {
            try await client.loginAndConnect(intents: [.guilds, .guildMessages])
            print("✅ Basic connection test passed")
            
            for await event in client.events {
                switch event {
                case .ready:
                    print("✅ Ready event received")
                    return
                case .error(let error):
                    print("❌ Error: \(error)")
                    return
                default:
                    break
                }
            }
        } catch {
            print("❌ Connection failed: \(error)")
        }
    }
}
```

### 2. Heartbeat Management Test

```swift
// Test enhanced heartbeat functionality
let config = DiscordConfiguration(
    heartbeatJitter: 0.1,
    maxMissedHeartbeats: 3
)
let client = DiscordClient(token: token, configuration: config)

// Connect and monitor heartbeat
try await client.loginAndConnect(intents: [.guilds])

// Check heartbeat latency
if let latency = await client.gatewayClient.heartbeatLatency() {
    print("✅ Heartbeat latency: \(latency)ms")
}
```

### 3. Shard Management Test

```swift
// Test auto-recovery and health monitoring
let autoRecovery = ShardingGatewayManager.AutoRecoveryConfig(
    enabled: true,
    maxRetryAttempts: 3,
    retryDelay: 30.0,
    healthCheckInterval: 60.0
)

let shardManager = await ShardingGatewayManager(
    token: token,
    configuration: .init(shardCount: .automatic),
    intents: [.guilds, .guildMessages],
    autoRecovery: autoRecovery
)

try await shardManager.connect()
await shardManager.startHealthMonitoring()

// Check shard health
let health = await shardManager.healthCheck()
print("✅ Shard health: \(health.readyShards)/\(health.totalShards)")
```

### 4. Developer Utilities Test

```swift
// Test BotUtils functionality
let formattedText = BotUtils.MessageFormat.bold("Test") + " " + 
                   BotUtils.MessageFormat.italic("Formatting")
print("✅ Message formatting: \(formattedText)")

let timestamp = BotUtils.TimeUtils.discordTimestamp(Date(), style: .relative)
print("✅ Timestamp: \(timestamp)")

let isValid = BotUtils.Validation.isValidDiscordTag("User#1234")
print("✅ Validation result: \(isValid)")

let embed = BotUtils.EmbedBuilder.createEmbed(
    title: "Test Embed",
    description: "Testing embed builder",
    color: 0x00ff00
)
print("✅ Embed created: \(embed.title ?? "")")
```

## 📊 API Coverage Testing

### 1. Template API Test

```swift
// Test guild template functionality
let templates = try await client.getGuildTemplates(guildId: guildId)
print("✅ Retrieved \(templates.count) templates")

let newTemplate = TemplateCreate(name: "Test Template", description: "Test")
let created = try await client.createGuildTemplate(guildId: guildId, template: newTemplate)
print("✅ Created template: \(created.code)")
```

### 2. Voice State Test

```swift
// Test voice state management
let voiceRegions = try await client.getVoiceRegions()
print("✅ Retrieved \(voiceRegions.count) voice regions")

let guildVoiceStates = try await client.getGuildVoiceStates(guildId: guildId)
print("✅ Retrieved \(guildVoiceStates.count) voice states")
```

### 3. Onboarding Test

```swift
// Test guild onboarding
let onboarding = try await client.getGuildOnboarding(guildId: guildId)
print("✅ Retrieved onboarding: \(onboarding.enabled)")

let welcomeScreen = try await client.getGuildWelcomeScreen(guildId: guildId)
print("✅ Retrieved welcome screen")
```

## 🔍 Discord API Compliance Verification

### 1. Rate Limiting Test

```swift
// Test rate limiting compliance
for i in 1...10 {
    do {
        let _ = try await client.getGuild(guildId: guildId)
        print("✅ Request \(i) succeeded")
    } catch {
        print("⚠️ Request \(i) rate limited: \(error)")
    }
}
```

### 2. Intent Validation Test

```swift
// Test privileged intents handling
let privilegedIntents: [GatewayIntents] = [
    .messageContent,
    .guildMembers,
    .guildPresences
]

for intent in privilegedIntents {
    do {
        try await client.loginAndConnect(intents: [intent])
        print("✅ Intent \(intent) accepted")
    } catch {
        print("⚠️ Intent \(intent) rejected: \(error)")
    }
}
```

### 3. Error Handling Test

```swift
// Test error handling for invalid requests
do {
    let _ = try await client.getGuild(guildId: "invalid")
    print("❌ Should have failed")
} catch {
    print("✅ Properly handled invalid guild ID: \(error)")
}
```

## 🏗️ Production Testing

### 1. Load Testing

```swift
// Test multiple concurrent connections
let clients = (1...5).map { _ in DiscordClient(token: token) }

try await withThrowingTaskGroup(of: Void.self) { group in
    for client in clients {
        group.addTask {
            try await client.loginAndConnect(intents: [.guilds])
            print("✅ Client connected successfully")
        }
    }
    
    try await group.waitForAll()
}
```

### 2. Memory Leak Testing

```swift
// Test for memory leaks in long-running operations
for _ in 1...100 {
    let client = DiscordClient(token: token)
    
    do {
        try await client.loginAndConnect(intents: [.guilds])
        await client.close()
    } catch {
        print("❌ Memory leak test failed: \(error)")
    }
}

print("✅ Memory leak test completed")
```

## 📋 Pre-Release Checklist

### ✅ Build Verification
- [ ] `swift build` succeeds
- [ ] `swift build -c release` succeeds
- [ ] No compilation warnings
- [ ] All tests pass: `swift test`

### ✅ API Compliance
- [ ] All Discord API endpoints follow proper REST conventions
- [ ] Rate limiting is properly implemented
- [ ] Error handling follows Discord API error responses
- [ ] Intent validation works correctly

### ✅ Code Quality
- [ ] Code follows Swift conventions
- [ ] Documentation is complete and accurate
- [ ] Examples are functional and well-documented
- [ ] No deprecated APIs are used

### ✅ Performance
- [ ] Memory usage is within acceptable limits
- [ ] Connection establishment is timely
- [ ] Heartbeat latency is acceptable (<1000ms)
- [ ] Shard recovery works correctly

## 🚀 Deployment Commands

### 1. Create Release Branch

```bash
# Create release branch
git checkout -b release/v0.13.0

# Merge changes
git merge feature/v0.13.0-testing

# Tag the release
git tag -a v0.13.0 -m "Release v0.13.0 - Professional Discord API Library"

# Push to remote
git push origin release/v0.13.0
git push origin v0.13.0
```

### 2. Archive for Distribution

```bash
# Create source archive
git archive --format=zip --prefix=SwiftDisc-0.13.0/ v0.13.0 > SwiftDisc-0.13.0.zip

# Create tar.gz archive
git archive --format=tar.gz --prefix=SwiftDisc-0.13.0/ v0.13.0 > SwiftDisc-0.13.0.tar.gz
```

### 3. Publish to Swift Package Index

```bash
# Verify package.swift is valid
swift package validate

# Test package resolution
swift package resolve

# Update Package.resolved if needed
swift package update
```

## 🐛 Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   # Clean and rebuild
   swift build --clean
   rm -rf .build
   swift build
   ```

2. **Test Failures**
   ```bash
   # Run tests with detailed output
   swift test --verbose --filter testFunctionName
   ```

3. **Connection Issues**
   ```bash
   # Verify token and network connectivity
   curl -H "Authorization: Bot YOUR_TOKEN" https://discord.com/api/v10/users/@me
   ```

4. **Permission Issues**
   ```bash
   # Check file permissions
   ls -la
   chmod +x Scripts/*.sh
   ```

## 📞 Support

If you encounter issues during testing:

1. Check the [Documentation](./docs/README.md)
2. Review the [Examples](./Examples/)
3. Join our [Discord Server](https://discord.gg/6nS2KqxQtj)
4. Check existing [GitHub Issues](https://github.com/M1tsumi/SwiftDisc/issues)

---

**Note**: Always test in a development environment before deploying to production.
