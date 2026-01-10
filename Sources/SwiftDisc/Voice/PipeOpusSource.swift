//
//  PipeOpusSource.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

// Reads length-prefixed Opus frames from a FileHandle.
// Format: [u32 little-endian length][<length> bytes payload] repeated.
public final class PipeOpusSource: VoiceAudioSource {
    private let handle: FileHandle
    private let defaultFrameDurationMs: Int

    public init(handle: FileHandle, defaultFrameDurationMs: Int = 20) {
        self.handle = handle
        self.defaultFrameDurationMs = defaultFrameDurationMs
    }

    public func nextFrame() async throws -> OpusFrame? {
        // Read 4 bytes length (LE)
        let lenData = try self.readExact(count: 4)
        if lenData.count == 0 { return nil }
        if lenData.count < 4 { return nil }
        let length = lenData.withUnsafeBytes { ptr -> UInt32 in
            let b = ptr.bindMemory(to: UInt8.self)
            return UInt32(b[0]) | (UInt32(b[1]) << 8) | (UInt32(b[2]) << 16) | (UInt32(b[3]) << 24)
        }
        if length == 0 { return nil }
        let payload = try self.readExact(count: Int(length))
        if payload.count < Int(length) { return nil }
        return OpusFrame(data: payload, durationMs: defaultFrameDurationMs)
    }

    private func readExact(count: Int) throws -> Data {
        var out = Data(); out.reserveCapacity(count)
        while out.count < count {
            let chunk = try handle.read(upToCount: count - out.count) ?? Data()
            if chunk.isEmpty { break }
            out.append(chunk)
        }
        return out
    }
}
