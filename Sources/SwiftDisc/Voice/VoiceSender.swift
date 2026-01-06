//
//  VoiceSender.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation
#if canImport(Network)
import Network
#endif

protocol VoiceEncryptor {
    func seal(nonce: Data, key: [UInt8], plaintext: Data) throws -> Data
}

final class RTPVoiceSender {
    private var sequence: UInt16 = 0
    private var timestamp: UInt32 = 0
    private let ssrc: UInt32
    private let key: [UInt8]
    private let encryptor: VoiceEncryptor
    #if canImport(Network)
    private let connection: NWConnection
    #endif

    init(ssrc: UInt32, key: [UInt8], host: String, port: UInt16, encryptor: VoiceEncryptor) {
        self.ssrc = ssrc
        self.key = key
        self.encryptor = encryptor
        #if canImport(Network)
        let params = NWParameters.udp
        self.connection = NWConnection(to: .hostPort(host: .name(host, nil), port: NWEndpoint.Port(rawValue: port)!), using: params)
        self.connection.start(queue: .global())
        #endif
    }

    func sendOpusFrame(_ opus: Data, samplesPerFrame: UInt32 = 960) async {
        // RTP header (12 bytes)
        var header = Data(count: 12)
        // Version 2, payload type 0x78 (dynamic, like Discord typical), marker 0
        header[0] = 0x80
        header[1] = 0x78
        // Sequence big endian
        var seqBE = sequence.bigEndian
        withUnsafeBytes(of: &seqBE) { header.replaceSubrange(2..<4, with: $0) }
        // Timestamp big endian
        var tsBE = timestamp.bigEndian
        withUnsafeBytes(of: &tsBE) { header.replaceSubrange(4..<8, with: $0) }
        // SSRC big endian
        var ssrcBE = ssrc.bigEndian
        withUnsafeBytes(of: &ssrcBE) { header.replaceSubrange(8..<12, with: $0) }

        // Nonce for xsalsa20_poly1305 is 24 bytes. Discord voice convention uses RTP header as prefix + zeros.
        var nonce = Data(count: 24)
        nonce.replaceSubrange(0..<12, with: header)
        // remaining 12 bytes remain zero

        // Encrypt
        guard !key.isEmpty else { return }
        guard let sealed = try? encryptor.seal(nonce: nonce, key: key, plaintext: opus) else { return }

        var packet = Data()
        packet.append(header)
        packet.append(sealed)

        // Send
        #if canImport(Network)
        connection.send(content: packet, completion: .contentProcessed { _ in })
        #endif

        // Advance counters
        sequence &+= 1
        timestamp &+= samplesPerFrame // 48kHz * 20ms = 960
    }
}
