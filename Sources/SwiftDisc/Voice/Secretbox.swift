import Foundation

// Minimal pure-Swift XSalsa20-Poly1305 (NaCl secretbox) implementation
// API: seal(nonce:key:plaintext:) -> ciphertext_with_mac

private enum SecretboxError: Error {
    case authenticationFailed
}

struct Secretbox: VoiceEncryptor {
    func seal(nonce: Data, key: [UInt8], plaintext: Data) throws -> Data {
        precondition(key.count == 32, "Secretbox key must be 32 bytes")
        precondition(nonce.count == 24, "Secretbox nonce must be 24 bytes")
        let k = Array(key)
        let n = Array(nonce)
        // Subkey using HSalsa20 with first 16 bytes of nonce
        let subKey = hsalsa20(nonce16: Array(n[0..<16]), key: k)
        // Salsa20 keystream starting with nonce tail (8 bytes)
        let ks = salsa20Stream(key: subKey, nonce8: Array(n[16..<24]), count: 32 + plaintext.count)
        // Poly1305 one-time key is first 32 bytes of keystream
        let polyKey = Array(ks[0..<32])
        // Ciphertext = plaintext XOR keystream starting at offset 32
        var cipher = Data(count: plaintext.count)
        plaintext.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            for i in 0..<plaintext.count {
                cipher[i] = buffer.load(fromByteOffset: i, as: UInt8.self) ^ ks[32 + i]
            }
        }
        // Compute Poly1305 MAC over ciphertext
        let mac = poly1305Authenticate(message: Array(cipher), key: polyKey)
        // Output: MAC (16) + ciphertext
        var out = Data()
        out.append(contentsOf: mac)
        out.append(cipher)
        return out
    }

    func open(nonce: Data, key: [UInt8], box: Data) throws -> Data {
        precondition(key.count == 32, "Secretbox key must be 32 bytes")
        precondition(nonce.count == 24, "Secretbox nonce must be 24 bytes")
        precondition(box.count >= 16, "Secretbox box must be at least 16 bytes (MAC)")

        let k = Array(key)
        let n = Array(nonce)
        let mac = Array(box[0..<16])
        let cipher = Array(box[16..<box.count])

        let subKey = hsalsa20(nonce16: Array(n[0..<16]), key: k)
        let ks = salsa20Stream(key: subKey, nonce8: Array(n[16..<24]), count: 32 + cipher.count)
        let polyKey = Array(ks[0..<32])

        let expectedMac = poly1305Authenticate(message: cipher, key: polyKey)
        guard expectedMac == mac else { throw SecretboxError.authenticationFailed }

        var plain = Data(count: cipher.count)
        for i in 0..<cipher.count {
            plain[i] = cipher[i] ^ ks[32 + i]
        }
        return plain
    }
}

// MARK: - Salsa20/HSalsa20 core

private func rotateLeft(_ x: UInt32, by n: UInt32) -> UInt32 { (x << n) | (x >> (32 - n)) }

// Quarter round operating on indices into the state array to avoid overlapping inout access
private func quarterRound(_ x: inout [UInt32], _ a: Int, _ b: Int, _ c: Int, _ d: Int) {
    var y0 = x[a]
    var y1 = x[b]
    var y2 = x[c]
    var y3 = x[d]
    y1 ^= rotateLeft(y0 &+ y3, by: 7)
    y2 ^= rotateLeft(y1 &+ y0, by: 9)
    y3 ^= rotateLeft(y2 &+ y1, by: 13)
    y0 ^= rotateLeft(y3 &+ y2, by: 18)
    x[a] = y0
    x[b] = y1
    x[c] = y2
    x[d] = y3
}

private func littleEndian(_ b: ArraySlice<UInt8>) -> UInt32 {
    var v: UInt32 = 0
    var i = 0
    for byte in b {
        v |= UInt32(byte) << (8 * i)
        i += 1
    }
    return v
}

private func toBytesLE(_ x: UInt32) -> [UInt8] {
    return [UInt8(x & 0xff), UInt8((x >> 8) & 0xff), UInt8((x >> 16) & 0xff), UInt8((x >> 24) & 0xff)]
}

private let sigma: [UInt8] = Array("expand 32-byte k".utf8)

private func hsalsa20(nonce16 n: [UInt8], key k: [UInt8]) -> [UInt8] {
    var state = [UInt32](repeating: 0, count: 16)
    state[0]  = littleEndian(sigma[0..<4])
    state[5]  = littleEndian(sigma[4..<8])
    state[10] = littleEndian(sigma[8..<12])
    state[15] = littleEndian(sigma[12..<16])

    state[1]  = littleEndian(k[0..<4])
    state[2]  = littleEndian(k[4..<8])
    state[3]  = littleEndian(k[8..<12])
    state[4]  = littleEndian(k[12..<16])

    state[11] = littleEndian(k[16..<20])
    state[12] = littleEndian(k[20..<24])
    state[13] = littleEndian(k[24..<28])
    state[14] = littleEndian(k[28..<32])

    state[6]  = littleEndian(n[0..<4])
    state[7]  = littleEndian(n[4..<8])
    state[8]  = littleEndian(n[8..<12])
    state[9]  = littleEndian(n[12..<16])

    var x = state
    for _ in 0..<10 {
        // column rounds
        quarterRound(&x, 0, 4, 8, 12)
        quarterRound(&x, 5, 9, 13, 1)
        quarterRound(&x, 10, 14, 2, 6)
        quarterRound(&x, 15, 3, 7, 11)
        // row rounds
        quarterRound(&x, 0, 1, 2, 3)
        quarterRound(&x, 5, 6, 7, 4)
        quarterRound(&x, 10, 11, 8, 9)
        quarterRound(&x, 15, 12, 13, 14)
    }

    var out = [UInt8]()
    out += toBytesLE(x[0])
    out += toBytesLE(x[5])
    out += toBytesLE(x[10])
    out += toBytesLE(x[15])
    out += toBytesLE(x[6])
    out += toBytesLE(x[7])
    out += toBytesLE(x[8])
    out += toBytesLE(x[9])
    return out
}

private func salsa20Block(key: [UInt8], nonce: [UInt8], counter: UInt64) -> [UInt8] {
    var state = [UInt32](repeating: 0, count: 16)
    state[0]  = littleEndian(sigma[0..<4])
    state[5]  = littleEndian(sigma[4..<8])
    state[10] = littleEndian(sigma[8..<12])
    state[15] = littleEndian(sigma[12..<16])

    state[1]  = littleEndian(key[0..<4])
    state[2]  = littleEndian(key[4..<8])
    state[3]  = littleEndian(key[8..<12])
    state[4]  = littleEndian(key[12..<16])

    state[11] = littleEndian(key[16..<20])
    state[12] = littleEndian(key[20..<24])
    state[13] = littleEndian(key[24..<28])
    state[14] = littleEndian(key[28..<32])

    // nonce 8 bytes (little-endian)
    state[6]  = littleEndian(nonce[0..<4])
    state[7]  = littleEndian(nonce[4..<8])
    // counter split into 2 words little-endian
    let c0 = UInt32(counter & 0xffffffff)
    let c1 = UInt32(counter >> 32)
    state[8] = c0
    state[9] = c1

    var x = state
    for _ in 0..<10 {
        quarterRound(&x, 0, 4, 8, 12)
        quarterRound(&x, 5, 9, 13, 1)
        quarterRound(&x, 10, 14, 2, 6)
        quarterRound(&x, 15, 3, 7, 11)

        quarterRound(&x, 0, 1, 2, 3)
        quarterRound(&x, 5, 6, 7, 4)
        quarterRound(&x, 10, 11, 8, 9)
        quarterRound(&x, 15, 12, 13, 14)
    }

    var out = [UInt8](repeating: 0, count: 64)
    for i in 0..<16 {
        let z = x[i] &+ state[i]
        let bytes = toBytesLE(z)
        out[i*4+0] = bytes[0]
        out[i*4+1] = bytes[1]
        out[i*4+2] = bytes[2]
        out[i*4+3] = bytes[3]
    }
    return out
}

private func salsa20Stream(key: [UInt8], nonce8: [UInt8], count: Int) -> [UInt8] {
    var out = [UInt8]()
    out.reserveCapacity(count)
    var ctr: UInt64 = 0
    while out.count < count {
        let block = salsa20Block(key: key, nonce: nonce8, counter: ctr)
        let toCopy = min(64, count - out.count)
        out += block[0..<toCopy]
        ctr &+= 1
    }
    return out
}

// MARK: - Poly1305 (RFC 8439)

private func clampR(_ r: inout [UInt8]) {
    r[3]  &= 15
    r[7]  &= 15
    r[11] &= 15
    r[15] &= 15
    r[4]  &= 252
    r[8]  &= 252
    r[12] &= 252
}

private func loadLE(_ b: ArraySlice<UInt8>) -> UInt32 {
    var v: UInt32 = 0
    var i = 0
    for byte in b { v |= UInt32(byte) << (8 * i); i += 1 }
    return v
}

private func poly1305Authenticate(message: [UInt8], key: [UInt8]) -> [UInt8] {
    precondition(key.count == 32)
    var r = Array(key[0..<16])
    clampR(&r)
    let s = Array(key[16..<32])

    var r0 = UInt32(loadLE(r[0..<4])) & 0x3ffffff
    var r1 = (UInt32(loadLE(r[3..<7])) >> 2) & 0x3ffff03
    var r2 = (UInt32(loadLE(r[6..<10])) >> 4) & 0x3ffc0ff
    var r3 = (UInt32(loadLE(r[9..<13])) >> 6) & 0x3f03fff
    var r4 = (UInt32(loadLE(r[12..<16])) >> 8) & 0x00fffff

    var h0: UInt32 = 0, h1: UInt32 = 0, h2: UInt32 = 0, h3: UInt32 = 0, h4: UInt32 = 0
    let r1_5 = r1 * 5
    let r2_5 = r2 * 5
    let r3_5 = r3 * 5
    let r4_5 = r4 * 5

    var i = 0
    let bytes = message
    while i < bytes.count {
        let t0 = UInt32(loadLE(bytes[i..<min(i+4, bytes.count)]))
        let t1 = UInt32(loadLE(bytes[min(i+3, bytes.count)..<min(i+7, bytes.count)])) >> 2
        let t2 = UInt32(loadLE(bytes[min(i+6, bytes.count)..<min(i+10, bytes.count)])) >> 4
        let t3 = UInt32(loadLE(bytes[min(i+9, bytes.count)..<min(i+13, bytes.count)])) >> 6
        let t4 = UInt32(loadLE(bytes[min(i+12, bytes.count)..<min(i+16, bytes.count)])) >> 8

        h0 &+= t0 & 0x3ffffff
        h1 &+= t1 & 0x3ffffff
        h2 &+= t2 & 0x3ffffff
        h3 &+= t3 & 0x3ffffff
        h4 &+= t4 & 0x3ffffff

        // Add the 1 bit
        h4 &+= 1 << 24

        var d0 = (UInt64(h0) * UInt64(r0)) + (UInt64(h1) * UInt64(r4_5)) + (UInt64(h2) * UInt64(r3_5)) + (UInt64(h3) * UInt64(r2_5)) + (UInt64(h4) * UInt64(r1_5))
        var d1 = (UInt64(h0) * UInt64(r1)) + (UInt64(h1) * UInt64(r0)) + (UInt64(h2) * UInt64(r4_5)) + (UInt64(h3) * UInt64(r3_5)) + (UInt64(h4) * UInt64(r2_5))
        var d2 = (UInt64(h0) * UInt64(r2)) + (UInt64(h1) * UInt64(r1)) + (UInt64(h2) * UInt64(r0)) + (UInt64(h3) * UInt64(r4_5)) + (UInt64(h4) * UInt64(r3_5))
        var d3 = (UInt64(h0) * UInt64(r3)) + (UInt64(h1) * UInt64(r2)) + (UInt64(h2) * UInt64(r1)) + (UInt64(h3) * UInt64(r0)) + (UInt64(h4) * UInt64(r4_5))
        var d4 = (UInt64(h0) * UInt64(r4)) + (UInt64(h1) * UInt64(r3)) + (UInt64(h2) * UInt64(r2)) + (UInt64(h3) * UInt64(r1)) + (UInt64(h4) * UInt64(r0))

        var c: UInt32
        c = UInt32(d0 & 0x3ffffff); d0 >>= 26; h0 = c
        d1 &+= d0; c = UInt32(d1 & 0x3ffffff); d1 >>= 26; h1 = c
        d2 &+= d1; c = UInt32(d2 & 0x3ffffff); d2 >>= 26; h2 = c
        d3 &+= d2; c = UInt32(d3 & 0x3ffffff); d3 >>= 26; h3 = c
        d4 &+= d3; c = UInt32(d4 & 0x3ffffff); d4 >>= 26; h4 = c

        // partial reduction
        let carry = h4 >> 26; h4 &= 0x3ffffff; h0 &+= carry * 5
        let carry2 = h0 >> 26; h0 &= 0x3ffffff; h1 &+= carry2

        i += 16
    }

    // Final reduction
    var g0 = h0 &+ 5
    var g1 = h1 &+ (g0 >> 26); g0 &= 0x3ffffff
    var g2 = h2 &+ (g1 >> 26); g1 &= 0x3ffffff
    var g3 = h3 &+ (g2 >> 26); g2 &= 0x3ffffff
    var g4 = h4 &+ (g3 >> 26) - (1 << 26); g3 &= 0x3ffffff

    var mask = (g4 >> 31) - 1
    g0 &= mask; g1 &= mask; g2 &= mask; g3 &= mask; g4 &= mask
    mask = ~mask
    h0 = (h0 & mask) | g0
    h1 = (h1 & mask) | g1
    h2 = (h2 & mask) | g2
    h3 = (h3 & mask) | g3
    h4 = (h4 & mask) | g4

    // Serialize h
    var f0 = (h0 | (h1 << 26)) & 0xffffffff
    var f1 = ((h1 >> 6) | (h2 << 20)) & 0xffffffff
    var f2 = ((h2 >> 12) | (h3 << 14)) & 0xffffffff
    var f3 = ((h3 >> 18) | (h4 << 8)) & 0xffffffff

    // Add s
    var out = [UInt8](repeating: 0, count: 16)
    var carry: UInt64 = 0
    func addLE(_ value: UInt32, _ s: ArraySlice<UInt8>, _ offset: Int) {
        var sum = UInt64(value)
        for i in 0..<4 {
            sum += UInt64(s[s.startIndex + i]) << (8 * i)
        }
        sum += carry
        out[offset + 0] = UInt8(sum & 0xff)
        out[offset + 1] = UInt8((sum >> 8) & 0xff)
        out[offset + 2] = UInt8((sum >> 16) & 0xff)
        out[offset + 3] = UInt8((sum >> 24) & 0xff)
        carry = sum >> 32
    }
    addLE(f0, s[0..<4], 0)
    addLE(f1, s[4..<8], 4)
    addLE(f2, s[8..<12], 8)
    addLE(f3, s[12..<16], 12)
    return out
}
