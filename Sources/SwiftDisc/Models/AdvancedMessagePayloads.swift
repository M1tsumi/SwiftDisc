//
//  AdvancedMessagePayloads.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct V2MessagePayload: Encodable {
    public var content: String?
    public var flags: Int?
    public var components: [JSONValue]?

    public init(content: String? = nil, flags: Int? = nil, components: [JSONValue]? = nil) {
        self.content = content
        self.flags = flags
        self.components = components
    }

    public func asJSON() -> [String: JSONValue] {
        var dict: [String: JSONValue] = [:]
        if let content { dict["content"] = .string(content) }
        if let flags { dict["flags"] = .int(flags) }
        if let components { dict["components"] = .array(components) }
        return dict
    }
}

public struct PollPayload: Encodable {
    public var question: String
    public var answers: [String]
    public var durationSeconds: Int
    public var allowMultiple: Bool
    public var extra: [String: JSONValue]?

    public init(question: String, answers: [String], durationSeconds: Int, allowMultiple: Bool = false, extra: [String: JSONValue]? = nil) {
        self.question = question
        self.answers = answers
        self.durationSeconds = durationSeconds
        self.allowMultiple = allowMultiple
        self.extra = extra
    }

    // Builds a Discord-style poll object with question.text and answers list.
    public func pollJSON() -> [String: JSONValue] {
        var poll: [String: JSONValue] = [
            "question": .object(["text": .string(question)]),
            "answers": .array(answers.enumerated().map { idx, text in
                .object([
                    "answer_id": .int(idx + 1),
                    "poll_media": .object(["text": .string(text)])
                ])
            }),
            "allow_multiple": .bool(allowMultiple),
            "duration": .int(durationSeconds)
        ]
        if let extra {
            for (k, v) in extra { poll[k] = v }
        }
        return poll
    }
}
