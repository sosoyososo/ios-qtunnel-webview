import Foundation

/// iOS 端 clientConfig 条目 — 对应 server 上一个 backend
/// secret 与 crypto 必须与 server 端完全一致（决策 7：明文存储）
///
/// - qtunnelPort: qtunnel-server 在 VPS 上监听的端口
/// - backendHost/Port: 该 server 实际代理到的后端服务（通常 127.0.0.1:xxx）
struct ClientConfig: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var serverId: UUID
    var qtunnelPort: Int
    var cryptoMethod: CryptoMethod
    var secret: String
    var backendHost: String
    var backendPort: Int

    init(
        id: UUID = UUID(),
        name: String,
        serverId: UUID,
        qtunnelPort: Int,
        cryptoMethod: CryptoMethod,
        secret: String,
        backendHost: String = "127.0.0.1",
        backendPort: Int
    ) {
        self.id = id
        self.name = name
        self.serverId = serverId
        self.qtunnelPort = qtunnelPort
        self.cryptoMethod = cryptoMethod
        self.secret = secret
        self.backendHost = backendHost
        self.backendPort = backendPort
    }

    // 自定义解码器：老数据没有 qtunnelPort，默认为 0；忽略冗余字段
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.serverId = try c.decode(UUID.self, forKey: .serverId)
        self.qtunnelPort = try c.decodeIfPresent(Int.self, forKey: .qtunnelPort) ?? 0
        self.cryptoMethod = try c.decode(CryptoMethod.self, forKey: .cryptoMethod)
        self.secret = try c.decode(String.self, forKey: .secret)
        self.backendHost = try c.decodeIfPresent(String.self, forKey: .backendHost) ?? "127.0.0.1"
        self.backendPort = try c.decode(Int.self, forKey: .backendPort)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, serverId, qtunnelPort, cryptoMethod, secret, backendHost, backendPort
    }
}
