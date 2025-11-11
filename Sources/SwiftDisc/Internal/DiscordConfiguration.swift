import Foundation

public struct DiscordConfiguration {
    public var apiBaseURL: URL
    public var apiVersion: Int
    public var gatewayBaseURL: URL

    public init(apiBaseURL: URL = URL(string: "https://discord.com/api")!, apiVersion: Int = 10, gatewayBaseURL: URL = URL(string: "wss://gateway.discord.gg")!) {
        self.apiBaseURL = apiBaseURL
        self.apiVersion = apiVersion
        self.gatewayBaseURL = gatewayBaseURL
    }

    var restBase: URL { apiBaseURL.appendingPathComponent("v\(apiVersion)") }
}
