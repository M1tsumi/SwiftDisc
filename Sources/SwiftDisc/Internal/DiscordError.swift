import Foundation

public enum DiscordError: Error {
    case http(Int, String)
    case api(message: String, code: Int?)
    case decoding(Error)
    case encoding(Error)
    case network(Error)
    case gateway(String)
    case cancelled
}
