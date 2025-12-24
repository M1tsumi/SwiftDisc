import SwiftDisc
import Foundation

@main
struct ProfessionalBot {
    static func main() async {
        // Load configuration from environment variables
        guard let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] else {
            print("Error: DISCORD_BOT_TOKEN environment variable not set")
            return
        }
        
        // Create enhanced configuration with professional settings
        let config = DiscordConfiguration(
            heartbeatJitter: 0.1,
            maxMissedHeartbeats: 3
        )
        
        // Create Discord client with enhanced configuration
        let client = DiscordClient(token: token, configuration: config)
        
        // Set up auto-recovery configuration for sharding
        let autoRecovery = ShardingGatewayManager.AutoRecoveryConfig(
            enabled: true,
            maxRetryAttempts: 3,
            retryDelay: 30.0,
            healthCheckInterval: 60.0
        )
        
        // Create shard manager for large-scale deployment
        let shardManager = await ShardingGatewayManager(
            token: token,
            configuration: .init(
                shardCount: .automatic,
                connectionDelay: .staggered(interval: 5.0)
            ),
            intents: [
                .guilds,
                .guildMessages,
                .messageContent,
                .guildMembers,
                .guildPresences
            ],
            autoRecovery: autoRecovery
        )
        
        do {
            print("🚀 Starting Professional Bot...")
            print("📚 Documentation: https://github.com/M1tsumi/SwiftDisc/docs")
            
            // Start health monitoring
            await shardManager.startHealthMonitoring()
            
            // Connect with sharding
            try await shardManager.connect()
            
            print("✅ Bot connected successfully!")
            
            // Monitor shard health
            Task {
                while true {
                    try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                    
                    let health = await shardManager.healthCheck()
                    print("📊 Shard Health: \(health.readyShards)/\(health.totalShards) ready")
                    print("🏥 Health Score: \(String(format: "%.2f", health.healthScore))")
                    print("⚡ Average Latency: \(health.averageLatency?.formatted(.number.precision(.fractionLength(2))) ?? "N/A")ms")
                    
                    if !health.isHealthy {
                        print("⚠️ Warning: Some shards are unhealthy!")
                    }
                }
            }
            
            // Handle events from all shards
            for await shardedEvent in shardManager.events {
                await handleEvent(client: client, event: shardedEvent)
            }
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    private static func handleEvent(client: DiscordClient, event: ShardedEvent) async {
        switch event.event {
        case .ready(let info):
            print("🟢 Shard \(event.shardId) ready: \(info.user.username)")
            
        case .messageCreate(let message):
            await handleMessage(client: client, message: message, shardId: event.shardId)
            
        case .guildCreate(let guild):
            print("🏰 Joined guild: \(guild.name) (Shard: \(event.shardId))")
            
        case .guildMemberAdd(let member):
            await handleNewMember(client: client, member: member, shardId: event.shardId)
            
        default:
            break
        }
    }
    
    private static func handleMessage(client: DiscordClient, message: Message, shardId: Int) async {
        // Don't respond to bots or ourselves
        guard !message.author.bot && message.author.id != "YOUR_BOT_ID" else { return }
        
        // Parse command
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard content.hasPrefix("!") else { return }
        
        let parts = content.dropFirst().split(separator: " ")
        guard let command = parts.first else { return }
        
        switch command.lowercased() {
        case "ping":
            await handlePingCommand(client: client, message: message, shardId: shardId)
            
        case "help":
            await handleHelpCommand(client: client, message: message, shardId: shardId)
            
        case "utils":
            await handleUtilsCommand(client: client, message: message, shardId: shardId)
            
        case "embed":
            await handleEmbedCommand(client: client, message: message, shardId: shardId)
            
        case "time":
            await handleTimeCommand(client: client, message: message, shardId: shardId)
            
        case "validate":
            await handleValidateCommand(client: client, message: message, shardId: shardId)
            
        default:
            break
        }
    }
    
    private static func handlePingCommand(client: DiscordClient, message: Message, shardId: Int) async {
        do {
            let startTime = Date()
            let sentMessage = try await client.sendMessage(
                channelId: message.channel_id,
                content: "🏓 Pinging..."
            )
            
            let latency = Date().timeIntervalSince(startTime) * 1000
            
            // Update the message with latency info
            try await client.editMessage(
                channelId: message.channel_id,
                messageId: sentMessage.id,
                content: nil,
                embeds: [
                    Embed(
                        title: "🏓 Pong!",
                        description: "Latency: **\(String(format: "%.2f", latency))ms**",
                        color: 0x00ff00,
                        fields: [
                            Embed.Field(name: "Shard", value: "#\(shardId)", inline: true),
                            Embed.Field(name: "Channel", value: "<#\(message.channel_id)>", inline: true)
                        ]
                    )
                ]
            )
        } catch {
            print("❌ Error in ping command: \(error)")
        }
    }
    
    private static func handleHelpCommand(client: DiscordClient, message: Message, shardId: Int) async {
        do {
            let embed = BotUtils.EmbedBuilder.createEmbed(
                title: "🤖 Professional Bot Commands",
                description: "A comprehensive Discord bot built with SwiftDisc v0.13.0",
                color: 0x5865F2
            )
            
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "🔧 Utility Commands",
                value: """
                `!ping` - Test bot latency
                `!utils` - Demonstrate utility functions
                `!time` - Show Discord timestamps
                `!validate` - Test input validation
                `!embed` - Show embed building
                """,
                inline: false
            )
            
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "📚 Documentation",
                value: "[SwiftDisc Documentation](https://github.com/M1tsumi/SwiftDisc/docs)",
                inline: false
            )
            
            BotUtils.EmbedBuilder.setFooter(
                to: &embed,
                text: "SwiftDisc v0.13.0 • Professional Discord API Library",
                iconUrl: "https://raw.githubusercontent.com/M1tsumi/SwiftDisc/main/assets/logo.png"
            )
            
            try await client.sendMessage(
                channelId: message.channel_id,
                embeds: [embed]
            )
        } catch {
            print("❌ Error in help command: \(error)")
        }
    }
    
    private static func handleUtilsCommand(client: DiscordClient, message: Message, shardId: Int) async {
        do {
            let embed = BotUtils.EmbedBuilder.createEmbed(
                title: "🛠️ BotUtils Demonstration",
                description: "Showcasing the developer utilities in SwiftDisc",
                color: 0x00ff00
            )
            
            // Message formatting examples
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "📝 Message Formatting",
                value: """
                \(BotUtils.MessageFormat.bold("Bold text"))
                \(BotUtils.MessageFormat.italic("Italic text"))
                \(BotUtils.MessageFormat.code("Inline code"))
                \(BotUtils.MessageFormat.spoiler("Spoiler content")
                """,
                inline: false
            )
            
            // Time utilities
            let timestamp = BotUtils.TimeUtils.discordTimestamp(Date(), style: .relative)
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "⏰ Time Utilities",
                value: "Current time: \(timestamp)",
                inline: false
            )
            
            // Validation examples
            let validations = [
                ("Username", BotUtils.Validation.isValidUsername("SwiftDiscUser")),
                ("Discriminator", BotUtils.Validation.isValidDiscriminator("1234")),
                ("Discord Tag", BotUtils.Validation.isValidDiscordTag("User#1234")),
                ("Color Hex", BotUtils.Validation.isValidColorHex("#00ff00"))
            ]
            
            let validationResults = validations.map { name, isValid in
                "\(name): \(isValid ? "✅" : "❌")"
            }.joined(separator: "\n")
            
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "✅ Validation Examples",
                value: validationResults,
                inline: false
            )
            
            // Color utilities
            let randomColor = BotUtils.ColorUtils.randomColor()
            let contrastingColor = BotUtils.ColorUtils.contrastingTextColor(for: randomColor)
            
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "🎨 Color Utilities",
                value: """
                Random Color: #\(String(randomColor, radix: 16).uppercased())
                Contrasting Text: #\(String(contrastingColor, radix: 16).uppercased())
                """,
                inline: false
            )
            
            try await client.sendMessage(
                channelId: message.channel_id,
                embeds: [embed]
            )
        } catch {
            print("❌ Error in utils command: \(error)")
        }
    }
    
    private static func handleEmbedCommand(client: DiscordClient, message: Message, shardId: Int) async {
        do {
            var embed = BotUtils.EmbedBuilder.createEmbed(
                title: "🎨 Advanced Embed Example",
                description: "This embed demonstrates the BotUtils.EmbedBuilder",
                color: 0x9b59b6
            )
            
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "📊 Statistics",
                value: """
                • Total Users: 1,234,567
                • Total Servers: 8,901
                • Uptime: 99.9%
                """,
                inline: true
            )
            
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "⚡ Performance",
                value: """
                • Latency: 45ms
                • Memory: 128MB
                • CPU: 2.3%
                """,
                inline: true
            )
            
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "🔧 Features",
                value: """
                • Auto-recovery
                • Health monitoring
                • Professional sharding
                • Developer utilities
                """,
                inline: false
            )
            
            BotUtils.EmbedBuilder.setAuthor(
                to: &embed,
                name: "SwiftDisc Professional Bot",
                url: "https://github.com/M1tsumi/SwiftDisc",
                iconUrl: "https://raw.githubusercontent.com/M1tsumi/SwiftDisc/main/assets/logo.png"
            )
            
            BotUtils.EmbedBuilder.setFooter(
                to: &embed,
                text: "Shard \(shardId) • Requested by \(message.author.username)",
                iconUrl: message.author.avatarUrl()
            )
            
            BotUtils.EmbedBuilder.setImage(
                to: &embed,
                url: "https://raw.githubusercontent.com/M1tsumi/SwiftDisc/main/assets/banner.png"
            )
            
            try await client.sendMessage(
                channelId: message.channel_id,
                embeds: [embed]
            )
        } catch {
            print("❌ Error in embed command: \(error)")
        }
    }
    
    private static func handleTimeCommand(client: DiscordClient, message: Message, shardId: Int) async {
        do {
            let now = Date()
            
            let embed = BotUtils.EmbedBuilder.createEmbed(
                title: "⏰ Discord Timestamp Examples",
                description: "Demonstrating BotUtils.TimeUtils",
                color: 0x3498db
            )
            
            let timeStyles: [BotUtils.TimeUtils.TimestampStyle: String] = [
                .shortTime: "Short Time",
                .longTime: "Long Time",
                .shortDate: "Short Date",
                .longDate: "Long Date",
                .shortDateTime: "Short DateTime",
                .longDateTime: "Long DateTime",
                .relative: "Relative"
            ]
            
            for (style, name) in timeStyles {
                let timestamp = BotUtils.TimeUtils.discordTimestamp(now, style: style)
                BotUtils.EmbedBuilder.addField(
                    to: &embed,
                    name: name,
                    value: timestamp,
                    inline: true
                )
            }
            
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "📝 Raw Timestamp",
                value: "`\(Int(now.timeIntervalSince1970))`",
                inline: false
            )
            
            try await client.sendMessage(
                channelId: message.channel_id,
                embeds: [embed]
            )
        } catch {
            print("❌ Error in time command: \(error)")
        }
    }
    
    private static func handleValidateCommand(client: DiscordClient, message: Message, shardId: Int) async {
        do {
            let embed = BotUtils.EmbedBuilder.createEmbed(
                title: "✅ Input Validation Examples",
                description: "Testing BotUtils.Validation functions",
                color: 0x2ecc71
            )
            
            let testCases = [
                ("SwiftDiscUser", "Username"),
                ("1234", "Discriminator"),
                ("User#1234", "Discord Tag"),
                ("#00ff00", "Color Hex"),
                ("invalid@", "Invalid Username"),
                ("12", "Invalid Discriminator"),
                ("User#12", "Invalid Tag"),
                ("#gg0000", "Invalid Color")
            ]
            
            for (input, type) in testCases {
                let isValid: Bool
                switch type {
                case let t where t.contains("Username"):
                    isValid = BotUtils.Validation.isValidUsername(input)
                case let t where t.contains("Discriminator"):
                    isValid = BotUtils.Validation.isValidDiscriminator(input)
                case let t where t.contains("Tag"):
                    isValid = BotUtils.Validation.isValidDiscordTag(input)
                case let t where t.contains("Color"):
                    isValid = BotUtils.Validation.isValidColorHex(input)
                default:
                    isValid = false
                }
                
                let emoji = isValid ? "✅" : "❌"
                BotUtils.EmbedBuilder.addField(
                    to: &embed,
                    name: "\(type): \(input)",
                    value: emoji + " \(isValid ? "Valid" : "Invalid")",
                    inline: true
                )
            }
            
            try await client.sendMessage(
                channelId: message.channel_id,
                embeds: [embed]
            )
        } catch {
            print("❌ Error in validate command: \(error)")
        }
    }
    
    private static func handleNewMember(client: DiscordClient, member: GuildMember, shardId: Int) async {
        do {
            // Create a welcome embed using BotUtils
            var embed = BotUtils.EmbedBuilder.createEmbed(
                title: "👋 Welcome to the Server!",
                description: "Hello \(member.user?.username ?? "someone")! Welcome to our community.",
                color: 0x00ff00
            )
            
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "📚 Getting Started",
                value: """
                • Read the rules in #rules
                • Introduce yourself in #introductions
                • Check out our commands with `!help`
                """,
                inline: false
            )
            
            BotUtils.EmbedBuilder.addField(
                to: &embed,
                name: "🔗 Useful Links",
                value: """
                • [Documentation](https://github.com/M1tsumi/SwiftDisc/docs)
                • [Support Server](https://discord.gg/6nS2KqxQtj)
                • [GitHub](https://github.com/M1tsumi/SwiftDisc)
                """,
                inline: false
            )
            
            BotUtils.EmbedBuilder.setFooter(
                to: &embed,
                text: "SwiftDisc Professional Bot • Shard \(shardId)",
                iconUrl: "https://raw.githubusercontent.com/M1tsumi/SwiftDisc/main/assets/logo.png"
            )
            
            // Note: In a real bot, you'd need to implement a way to find the welcome channel
            // This is just a demonstration of the embed building
            print("👋 Would send welcome message to new member: \(member.user?.username ?? "unknown")")
        } catch {
            print("❌ Error handling new member: \(error)")
        }
    }
}
