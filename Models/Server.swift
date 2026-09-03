import Foundation

/// VPS 上的 qtunnel-server 条目
struct Server: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var host: String
    var port: Int

    init(id: UUID = UUID(), name: String, host: String, port: Int) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
    }
}
