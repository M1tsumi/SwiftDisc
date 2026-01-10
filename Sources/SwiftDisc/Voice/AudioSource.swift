//
//  AudioSource.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct OpusFrame {
    public let data: Data   // One Opus packet (20ms recommended)
    public let durationMs: Int
    public init(data: Data, durationMs: Int = 20) {
        self.data = data
        self.durationMs = durationMs
    }
}

public protocol VoiceAudioSource {
    // Returns the next Opus frame or nil when finished
    func nextFrame() async throws -> OpusFrame?
}
