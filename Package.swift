// swift-tools-version:6.2
import PackageDescription

// All Swift files inside the `Examples/` directory. Each example executable
// target points at the same `Examples` path with `sources:` listing the one
// file it owns; the rest must be excluded so SwiftPM does not report them as
// unhandled resources.
let allExampleFiles: [String] = [
    "AutocompleteBot.swift",
    "CogExample.swift",
    "CommandFrameworkBot.swift",
    "CommandsBot.swift",
    "ComponentsExample.swift",
    "ComponentsV2Bot.swift",
    "FileUploadBot.swift",
    "LinkedRolesBot.swift",
    "PingBot.swift",
    "ShardingBot.swift",
    "SlashBot.swift",
    "ThreadsAndScheduledEventsBot.swift",
    "ViewExample.swift",
    "WebhookBot.swift"
]

// README.md sits alongside the example sources and is not a Swift source.
let exampleNonSourceFiles: [String] = ["README.md"]

func exampleExcludes(keeping source: String) -> [String] {
    let others = allExampleFiles.filter { $0 != source }
    return others + exampleNonSourceFiles
}

let package = Package(
    name: "SwiftDisc",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(name: "SwiftDisc", targets: ["SwiftDisc"]),
        .library(name: "SwiftDiscAHCTransport", targets: ["SwiftDiscAHCTransport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
    ],
    targets: [
        .target(
            name: "SwiftDisc",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "SwiftDiscAHCTransport",
            dependencies: [
                "SwiftDisc",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Example executables so contributors can run sample bots quickly with `swift run <name>`.
        .executableTarget(
            name: "PingBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            exclude: exampleExcludes(keeping: "PingBot.swift"),
            sources: ["PingBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "SlashBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            exclude: exampleExcludes(keeping: "SlashBot.swift"),
            sources: ["SlashBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "CommandsBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            exclude: exampleExcludes(keeping: "CommandsBot.swift"),
            sources: ["CommandsBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "AutocompleteBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            exclude: exampleExcludes(keeping: "AutocompleteBot.swift"),
            sources: ["AutocompleteBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "FileUploadBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            exclude: exampleExcludes(keeping: "FileUploadBot.swift"),
            sources: ["FileUploadBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ComponentsExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            exclude: exampleExcludes(keeping: "ComponentsExample.swift"),
            sources: ["ComponentsExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ViewExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            exclude: exampleExcludes(keeping: "ViewExample.swift"),
            sources: ["ViewExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "WebhookBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            exclude: exampleExcludes(keeping: "WebhookBot.swift"),
            sources: ["WebhookBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ShardingBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            exclude: exampleExcludes(keeping: "ShardingBot.swift"),
            sources: ["ShardingBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ComponentsV2BotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            exclude: exampleExcludes(keeping: "ComponentsV2Bot.swift"),
            sources: ["ComponentsV2Bot.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SwiftDiscTests",
            dependencies: ["SwiftDisc"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
