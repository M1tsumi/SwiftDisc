// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SwiftDisc",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(name: "SwiftDisc", targets: ["SwiftDisc"])
    ],
    targets: [
        .target(
            name: "SwiftDisc",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Example executables so contributors can run sample bots quickly with `swift run <name>`.
        .executableTarget(
            name: "PingBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            sources: ["PingBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "SlashBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            sources: ["SlashBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "CommandsBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            sources: ["CommandsBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "AutocompleteBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            sources: ["AutocompleteBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "FileUploadBotExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            sources: ["FileUploadBot.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "ComponentsExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            sources: ["ComponentsExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "ViewExample",
            dependencies: ["SwiftDisc"],
            path: "Examples",
            sources: ["ViewExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SwiftDiscTests",
            dependencies: ["SwiftDisc"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
