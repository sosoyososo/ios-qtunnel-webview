import Foundation
import Network

/// 一条本地连接 ⇄ 一条到 tunnel-server 的加密隧道（与 Go client 语义一致：
/// 每次本地 TCP 连接独享一条隧道 + 独立 cipher，服务端按连接 NewCipher）。
/// - local 收到的字节 → 加密 → tunnel
/// - tunnel 解密收到的字节 → local
final class TCPForwarder: @unchecked Sendable {

    let local: NWConnection
    let tunnel: TunnelConnection
    private let onDone: (@Sendable () -> Void)?
    private var receiveStarted = false

    init(local: NWConnection, tunnel: TunnelConnection, onDone: (@Sendable () -> Void)? = nil) {
        self.local = local
        self.tunnel = tunnel
        self.onDone = onDone
    }

    func start() {
        // 先与本地端完成握手；请求数据会留在内核缓冲，待隧道 ready 后再 receive
        local.start(queue: .global())

        tunnel.onState = { [weak self] state in
            switch state {
            case .ready:
                self?.startLocalReceiveLoop()
            case .failed(let err):
                Log.error("TCPForwarder", "tunnel failed: \(err)")
                self?.stop()
            case .closed:
                self?.stop()
            default:
                break
            }
        }

        tunnel.onReceive = { [weak self] plain in
            guard let self else { return }
            self.local.send(content: plain, completion: .contentProcessed { error in
                if let error { Log.error("TCPForwarder", "local send error: \(error)") }
            })
        }

        tunnel.connect()
    }

    func stop() {
        // 只终结本 forwarder 自己的 local + 自己的 tunnel；不影响其它连接/实例
        local.cancel()
        tunnel.disconnect()
        onDone?()
    }

    // MARK: - Local → Tunnel (encrypt)

    private func startLocalReceiveLoop() {
        guard !receiveStarted else { return }
        receiveStarted = true
        receiveNext()
    }

    private func receiveNext() {
        local.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.tunnel.send(data)
            }
            if isComplete || error != nil {
                self.stop()
                return
            }
            self.receiveNext()
        }
    }
}
