import Foundation
#if canImport(Network)
import Network

final class RTPVoiceReceiver {
    private let ssrc: UInt32
    private let key: [UInt8]
    private let encryptor: Secretbox
    private let connection: NWConnection
    private let onFrame: (UInt16, UInt32, Data) -> Void

    init(ssrc: UInt32, key: [UInt8], host: String, port: UInt16, onFrame: @escaping (UInt16, UInt32, Data) -> Void) {
        self.ssrc = ssrc
        self.key = key
        self.encryptor = Secretbox()
        self.onFrame = onFrame
        let params = NWParameters.udp
        self.connection = NWConnection(to: .hostPort(host: .name(host, nil), port: NWEndpoint.Port(rawValue: port)!), using: params)
        self.connection.start(queue: .global())
    }

    func start() {
        receiveNext()
    }

    func stop() {
        connection.cancel()
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1500) { [weak self] data, _, _, error in
            guard let self else { return }
            if let data = data {
                self.handlePacket(data)
            }
            if error == nil {
                self.receiveNext()
            }
        }
    }

    private func handlePacket(_ data: Data) {
        guard data.count > 12 else { return }
        let header = data.subdata(in: 0..<12)
        let payload = data.subdata(in: 12..<data.count)

        var seq: UInt16 = 0
        seq |= UInt16(header[2]) << 8
        seq |= UInt16(header[3])

        var ts: UInt32 = 0
        ts |= UInt32(header[4]) << 24
        ts |= UInt32(header[5]) << 16
        ts |= UInt32(header[6]) << 8
        ts |= UInt32(header[7])

        var nonce = Data(count: 24)
        nonce.replaceSubrange(0..<12, with: header)

        guard let plain = try? encryptor.open(nonce: nonce, key: key, box: payload) else { return }
        onFrame(seq, ts, plain)
    }
}

#else

final class RTPVoiceReceiver {
    init(ssrc: UInt32, key: [UInt8], host: String, port: UInt16, onFrame: @escaping (UInt16, UInt32, Data) -> Void) {}
    func start() {}
    func stop() {}
}

#endif
