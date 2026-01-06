//
//  OAuth2HTTPClient.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// HTTP request structure for OAuth2 operations
public struct HTTPRequest {
    public enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    public enum Body {
        case json(Data)
        case formURLEncoded([String: Any])
        case none
    }

    public let method: Method
    public let url: String
    public let headers: [String: String]
    public let body: Body

    public init(
        method: Method,
        url: String,
        headers: [String: String] = [:],
        body: Body = .none
    ) throws {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

/// Generic HTTP client for OAuth2 operations
public class OAuth2HTTPClient {
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    public func perform<T: Decodable>(_ request: HTTPRequest) async throws -> T {
        guard let url = URL(string: request.url) else {
            throw OAuth2Error.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        // Set headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Set body
        switch request.body {
        case .json(let data):
            urlRequest.httpBody = data
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .formURLEncoded(let parameters):
            let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlRequest.httpBody = bodyString.data(using: .utf8)
            urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        case .none:
            break
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuth2Error.serverError
        }

        switch httpResponse.statusCode {
        case 200..<300:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        case 400:
            throw OAuth2Error.invalidRequest
        case 401:
            throw OAuth2Error.invalidClient
        case 403:
            throw OAuth2Error.accessDenied
        case 429:
            throw OAuth2Error.temporarilyUnavailable
        case 500..<600:
            throw OAuth2Error.serverError
        default:
            throw OAuth2Error.serverError
        }
    }
}

/// Empty response type for requests that don't return data
public struct EmptyResponse: Decodable {}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/OAuth2/OAuth2HTTPClient.swift