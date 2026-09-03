import Foundation
import Network

/// 单条 iOS↔qtunnel-server TCP 连接 — spec 01 §4.2
/// 所有字节流经 cipher 加密/解密
final class TunnelConnection: @unchecked Sendable {

    let host: String
    let port: Int
    let cipher: Cipher

    private var conn: NWConnection?
    private let lock = NSLock()

    /// receive handler 接受解密后的明文 bytes
    var onReceive: (@Sendable (Data) -> Void)?
    /// 状态变化（ready/failed/closed）
    var onState: (@Sendable (State) -> Void)?

    enum State: Sendable {
        case connecting, ready, failed(Error), closed
    }

    init(host: String, port: Int, cipher: Cipher) {
        self.host = host
        self.port = port
        self.cipher = cipher
    }

    func connect() {
        lock.lock()
        defer { lock.unlock() }
        guard conn == nil else { return }

        let conn = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(port)) ?? .any,
            using: .tcp
        )
        self.conn = conn

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onState?(.ready)
                self?.startReceiveLoop()
            case .failed(let err):
                self?.onState?(.failed(err))
            case .cancelled:
                self?.onState?(.closed)
            default:
                break
            }
        }
        conn.start(queue: .global())
    }

    func disconnect() {
        lock.lock()
        defer { lock.unlock() }
        conn?.cancel()
        conn = nil
    }

    /// 发送明文（内部加密）
    func send(_ plain: Data) {
        lock.lock()
        let conn = self.conn
        lock.unlock()
        guard let conn else { return }

        let ciphered = cipher.encrypt(plain)
        conn.send(content: ciphered, completion: .contentProcessed { error in
            if let error { Log.error("TunnelConnection", "send error: \(error)") }
        })
    }

    // MARK: - Private

    private func startReceiveLoop() {
        lock.lock()
        let conn = self.conn
        lock.unlock()
        guard let conn else { return }

        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                Log.error("TunnelConnection", "receive error: \(error)")
                return
            }
            if let data, !data.isEmpty {
                let plain = self.cipher.decrypt(data)
                self.onReceive?(plain)
            }
            if !isComplete {
                self.startReceiveLoop()
            }
        }
    }
}
