//
//  WebSocket.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum WebSocketMessage {
    case string(String)
    case data(Data)
}

protocol WebSocketClient {
    func send(_ message: WebSocketMessage) async throws
    func receive() async throws -> WebSocketMessage
    func close() async
}

final class URLSessionWebSocketAdapter: WebSocketClient {
    private let task: URLSessionWebSocketTask
    private let session: URLSession

    init(url: URL) {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 8
        self.session = URLSession(configuration: config)
        self.task = session.webSocketTask(with: url)
        self.task.resume()
    }

    func send(_ message: WebSocketMessage) async throws {
        switch message {
        case .string(let text):
            try await task.send(.string(text))
        case .data(let data):
            try await task.send(.data(data))
        }
    }

    func receive() async throws -> WebSocketMessage {
        let msg = try await task.receive()
        switch msg {
        case .string(let text):
            return .string(text)
        case .data(let data):
            return .data(data)
        @unknown default:
            return .string("")
        }
    }

    func close() async {
        task.cancel(with: .normalClosure, reason: nil)
    }
}

final class UnavailableWebSocketAdapter: WebSocketClient {
    func send(_ message: WebSocketMessage) async throws { throw DiscordError.gateway("WebSocket unavailable on this platform") }
    func receive() async throws -> WebSocketMessage { throw DiscordError.gateway("WebSocket unavailable on this platform") }
    func close() async { }
}
