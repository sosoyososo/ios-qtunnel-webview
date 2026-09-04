import Foundation

/// VPS 上的 qtunnel-server 条目 — 仅指定 host，不带端口
/// qtunnel-server 实际监听端口由 ClientConfig.qtunnelPort 持有
struct Server: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var host: String

    init(id: UUID = UUID(), name: String, host: String) {
        self.id = id
        self.name = name
        self.host = host
    }

    // 自定义解码器：忽略历史数据中的 port 字段
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.host = try c.decode(String.self, forKey: .host)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, host
    }
}
