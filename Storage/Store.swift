import Foundation
import Observation

/// 持久化容器 — spec 01 §6
/// 单 JSON 序列化整体读写；iOS 17+ `@Observable` 路径
@Observable
@MainActor
final class Store {

    struct Data: Codable, Sendable {
        var servers: [Server] = []
        var clientConfigs: [ClientConfig] = []
        var clientInstances: [ClientInstance] = []
        var webViews: [WebViewState] = []
    }

    private(set) var data: Data
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.data(forKey: Keys.store),
           let decoded = try? JSONDecoder().decode(Data.self, from: raw) {
            self.data = decoded
            Log.info("Store", "loaded: \(decoded.servers.count) servers, \(decoded.clientConfigs.count) configs")
        } else {
            self.data = Data()
            Log.info("Store", "initialized empty")
        }
    }

    // MARK: - Mutations
    // 全部重新赋值 data（@Observable 不跟踪嵌套 struct 修改）

    func upsertServer(_ server: Server) {
        var d = data
        upsert(&d.servers, server)
        data = d
        persist()
    }

    func deleteServer(_ id: UUID) {
        var d = data
        d.servers.removeAll { $0.id == id }
        let cfgIds = d.clientConfigs.filter { $0.serverId == id }.map(\.id)
        d.clientConfigs.removeAll { cfgIds.contains($0.id) }
        let instIds = d.clientInstances.filter { cfgIds.contains($0.clientConfigId) }.map(\.id)
        d.clientInstances.removeAll { instIds.contains($0.id) }
        d.webViews.removeAll { instIds.contains($0.clientInstanceId) }
        data = d
        persist()
    }

    func upsertClientConfig(_ cfg: ClientConfig) {
        var d = data
        upsert(&d.clientConfigs, cfg)
        data = d
        persist()
    }

    func deleteClientConfig(_ id: UUID) {
        var d = data
        d.clientConfigs.removeAll { $0.id == id }
        let instIds = d.clientInstances.filter { $0.clientConfigId == id }.map(\.id)
        d.clientInstances.removeAll { instIds.contains($0.id) }
        d.webViews.removeAll { instIds.contains($0.clientInstanceId) }
        data = d
        persist()
    }

    func upsertClientInstance(_ inst: ClientInstance) {
        var d = data
        upsert(&d.clientInstances, inst)
        data = d
        persist()
    }

    func deleteClientInstance(_ id: UUID) {
        var d = data
        d.clientInstances.removeAll { $0.id == id }
        d.webViews.removeAll { $0.clientInstanceId == id }
        data = d
        persist()
    }

    func upsertWebView(_ wv: WebViewState) {
        var d = data
        upsert(&d.webViews, wv)
        data = d
        persist()
    }

    func deleteWebView(_ id: UUID) {
        var d = data
        d.webViews.removeAll { $0.id == id }
        data = d
        persist()
    }

    func reset() {
        data = Data()
        persist()
    }

    // MARK: - Helpers

    private func upsert<T: Identifiable>(_ array: inout [T], _ item: T) {
        if let idx = array.firstIndex(where: { $0.id == item.id }) {
            array[idx] = item
        } else {
            array.append(item)
        }
    }

    private func persist() {
        do {
            let encoded = try JSONEncoder().encode(data)
            defaults.set(encoded, forKey: Keys.store)
        } catch {
            Log.error("Store", "persist failed: \(error)")
        }
    }
}
