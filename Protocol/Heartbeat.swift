import Foundation

/// 心跳 — spec 01 §4.3
/// 每 5 分钟发 1 字节 0x00（加密后）维持 server 端 idle timeout
/// 连续 2 次发送失败 → 调用方标记 stopped
actor Heartbeat {

    private var task: Task<Void, Never>?
    private weak var connection: TunnelConnection?
    let interval: Duration
    let payload: Data

    private(set) var consecutiveFailures: Int = 0

    init(connection: TunnelConnection, interval: Duration = .seconds(300)) {
        self.connection = connection
        self.interval = interval
        self.payload = Data([0x00])
    }

    func start() {
        stop()
        let interval = self.interval
        let payload = self.payload
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let conn = await self?.connection else { return }
                // 直接 send；TunnelConnection.send 内部加密
                conn.send(payload)
                // 注意：真正的失败检测需要 TunnelConnection 提供 send 回调，
                // 当前实现简化：假定 send 总会成功（NWConnection 异步 ack 暂忽略）
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
