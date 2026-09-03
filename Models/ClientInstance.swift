import Foundation

/// ClientInstance — 一条长连接 TCP（iOS 端 qtunnel-client 实例）
/// 默认每 ClientConfig 1 个；多开用于规避 head-of-line blocking
struct ClientInstance: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var clientConfigId: UUID
    /// 本地监听端口（0 = 未分配）；决策 1：随机
    var localPort: Int
    /// 状态字段（运行时由 StateMachine 更新，持久化时存最近一次）
    var status: Status

    enum Status: String, Codable, Sendable {
        case idle, handshaking, running, failed, stopped
    }

    init(
        id: UUID = UUID(),
        clientConfigId: UUID,
        localPort: Int = 0,
        status: Status = .idle
    ) {
        self.id = id
        self.clientConfigId = clientConfigId
        self.localPort = localPort
        self.status = status
    }
}
