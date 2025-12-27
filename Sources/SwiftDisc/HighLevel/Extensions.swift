import Foundation

public protocol SwiftDiscExtension {
    func onRegister(client: DiscordClient) async
    func onUnload(client: DiscordClient) async
}

public extension SwiftDiscExtension {
    func onRegister(client: DiscordClient) async {}
    func onUnload(client: DiscordClient) async {}
}
