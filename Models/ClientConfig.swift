import Foundation

/// iOS 端 clientConfig 条目 — 对应 server 上一个 backend
/// secret 与 crypto 必须与 server 端完全一致（决策 7：明文存储）
struct ClientConfig: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var serverId: UUID
    var cryptoMethod: CryptoMethod
    var secret: String
    var backendHost: String
    var backendPort: Int

    init(
        id: UUID = UUID(),
        name: String,
        serverId: UUID,
        cryptoMethod: CryptoMethod,
        secret: String,
        backendHost: String,
        backendPort: Int
    ) {
        self.id = id
        self.name = name
        self.serverId = serverId
        self.cryptoMethod = cryptoMethod
        self.secret = secret
        self.backendHost = backendHost
        self.backendPort = backendPort
    }
}
