import Foundation
import Network

/// 桥接本地连接与 tunnel 连接 — spec 01 §5.2
/// 本地 conn 收到的字节 → 加密 → 发到 tunnel
/// tunnel 收到的字节 → 解密 → 发到本地
final class TCPForwarder: @unchecked Sendable {

    let local: NWConnection
    let tunnel: TunnelConnection

    init(local: NWConnection, tunnel: TunnelConnection) {
        self.local = local
        self.tunnel = tunnel
    }

    func start() {
        startLocalReceiveLoop()
        startTunnelReceiveLoop()
    }

    func stop() {
        local.cancel()
        tunnel.disconnect()
    }

    // MARK: - Local → Tunnel (encrypt)

    private func startLocalReceiveLoop() {
        local.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.tunnel.send(data)
            }
            if isComplete || error != nil {
                self.stop()
                return
            }
            self.startLocalReceiveLoop()
        }
    }

    // MARK: - Tunnel → Local (decrypt)

    private func startTunnelReceiveLoop() {
        tunnel.onReceive = { [weak self] plain in
            guard let self else { return }
            self.local.send(content: plain, completion: .contentProcessed { error in
                if let error { Log.error("TCPForwarder", "local send error: \(error)") }
            })
        }
    }
}
