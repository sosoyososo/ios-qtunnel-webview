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

    func upsertServer(_ server: Server) {
        upsert(&data.servers, server)
        persist()
    }

    func deleteServer(_ id: UUID) {
        data.servers.removeAll { $0.id == id }
        // 级联删除
        let cfgIds = data.clientConfigs.filter { $0.serverId == id }.map(\.id)
        data.clientConfigs.removeAll { cfgIds.contains($0.id) }
        let instIds = data.clientInstances.filter { cfgIds.contains($0.clientConfigId) }.map(\.id)
        data.clientInstances.removeAll { instIds.contains($0.id) }
        data.webViews.removeAll { instIds.contains($0.clientInstanceId) }
        persist()
    }

    func upsertClientConfig(_ cfg: ClientConfig) {
        upsert(&data.clientConfigs, cfg)
        persist()
    }

    func deleteClientConfig(_ id: UUID) {
        data.clientConfigs.removeAll { $0.id == id }
        let instIds = data.clientInstances.filter { $0.clientConfigId == id }.map(\.id)
        data.clientInstances.removeAll { instIds.contains($0.id) }
        data.webViews.removeAll { instIds.contains($0.clientInstanceId) }
        persist()
    }

    func upsertClientInstance(_ inst: ClientInstance) {
        upsert(&data.clientInstances, inst)
        persist()
    }

    func deleteClientInstance(_ id: UUID) {
        data.clientInstances.removeAll { $0.id == id }
        data.webViews.removeAll { $0.clientInstanceId == id }
        persist()
    }

    func upsertWebView(_ wv: WebViewState) {
        upsert(&data.webViews, wv)
        persist()
    }

    func deleteWebView(_ id: UUID) {
        data.webViews.removeAll { $0.id == id }
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
