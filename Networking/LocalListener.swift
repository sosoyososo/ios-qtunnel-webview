import Foundation
import Network

/// 本地端口监听 — spec 01 §5.2
/// 监听 127.0.0.1:0（随机端口），把每条 accepted conn 交给 onConnection
actor LocalListener {

    private(set) var port: Int = 0
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    /// 启动监听并返回实际绑定端口
    func start(onConnection: @escaping @Sendable (NWConnection) -> Void) async throws -> Int {
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        // 仅本机可访问（避免意外暴露到 LAN）
        params.acceptLocalOnly = true

        guard let nwPort = NWEndpoint.Port(rawValue: 0) else {
            throw NSError(domain: "LocalListener", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid port 0"])
        }

        let listener = try NWListener(using: params, on: nwPort)
        self.listener = listener

        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    if let p = listener.port {
                        Task { await self.setPort(Int(p.rawValue)) }
                    }
                    // 已经有 listener，继续
                case .failed(let err):
                    continuation.resume(throwing: err)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] conn in
                guard let self else { return }
                Task { await self.register(conn) }
                onConnection(conn)
            }
            listener.start(queue: .global())

            // 等待 ready 拿到 port
            Task { [weak self] in
                while await self?.port == 0 {
                    try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
                }
                if let p = await self?.port {
                    continuation.resume(returning: p)
                }
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for conn in connections.values { conn.cancel() }
        connections.removeAll()
        port = 0
    }

    private func setPort(_ p: Int) { port = p }
    private func register(_ conn: NWConnection) {
        let key = ObjectIdentifier(conn)
        connections[key] = conn
    }
}
