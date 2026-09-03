import Foundation
import Observation

/// 全局 app 上下文 — 持有 Store + 各实体状态机的缓存
@Observable
@MainActor
final class AppEnvironment {
    let store: Store
    var serverStates: [UUID: ServerState] = [:]
    var clientInstanceStates: [UUID: ClientInstanceState] = [:]
    var webViewMachines: [UUID: WebViewStateMachine] = [:]

    init(store: Store = Store()) {
        self.store = store
        // 初始化所有 server 的状态机并启动周期 probe
        for server in store.data.servers {
            let state = ServerState(server: server)
            serverStates[server.id] = state
            state.startProbing()
        }
    }

    func serverState(for id: UUID) -> ServerState? {
        serverStates[id]
    }

    func instanceState(for instance: ClientInstance) -> ClientInstanceState {
        if let existing = clientInstanceStates[instance.id] { return existing }
        let s = ClientInstanceState(instance: instance)
        clientInstanceStates[instance.id] = s
        return s
    }

    func webViewMachine(for wv: WebViewState) -> WebViewStateMachine {
        if let existing = webViewMachines[wv.id] { return existing }
        let m = WebViewStateMachine(webView: wv)
        webViewMachines[wv.id] = m
        return m
    }

    /// 添加 server 后调用：创建状态机 + 启 probe
    func registerServer(_ server: Server) {
        let state = ServerState(server: server)
        serverStates[server.id] = state
        state.startProbing()
    }

    func removeServer(_ id: UUID) {
        serverStates[id]?.stopProbing()
        serverStates.removeValue(forKey: id)
    }

    /// 创建新 clientInstance，自动关联
    @discardableResult
    func createInstance(for config: ClientConfig) -> ClientInstance {
        let inst = ClientInstance(clientConfigId: config.id)
        store.upsertClientInstance(inst)
        return inst
    }
}
