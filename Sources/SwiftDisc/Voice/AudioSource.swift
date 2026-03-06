import Foundation

public struct OpusFrame: Sendable {
    public let data: Data   // One Opus packet (20ms recommended)
    public let durationMs: Int
    public init(data: Data, durationMs: Int = 20) {
        self.data = data
        self.durationMs = durationMs
    }
}

/// A source of Opus audio frames. Conforming types must be `Sendable` so they
/// can be passed into async voice-playback tasks.
public protocol VoiceAudioSource: Sendable {
    // Returns the next Opus frame or nil when finished
    func nextFrame() async throws -> OpusFrame?
}
