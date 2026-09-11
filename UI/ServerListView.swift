import SwiftUI

/// P1 — Server 列表 + Instances 快捷入口
struct ServerListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var path = NavigationPath()
    @State private var showingAdd = false
    @State private var showingHelp = false
    @State private var importAlert: ImportAlert?

    enum ImportAlert: Identifiable {
        case success(configName: String)
        case duplicate(configId: UUID, configName: String)
        case error(String)
        var id: String {
            switch self {
            case .success(let n):       return "ok-\(n)"
            case .duplicate(let id, _): return "dup-\(id.uuidString)"
            case .error(let m):         return "err-\(m)"
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                serverSection
                homeInstancesSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Servers")
            // 单点 navigationDestination —— 统一处理所有导航
            .navigationDestination(for: NavTarget.self) { target in
                switch target {
                case .server(let id):
                    if let server = env.store.data.servers.first(where: { $0.id == id }) {
                        ClientConfigListView(server: server)
                    }
                case .config(let id):
                    if let cfg = env.store.data.clientConfigs.first(where: { $0.id == id }),
                       let server = env.store.data.servers.first(where: { $0.id == cfg.serverId }) {
                        ClientInstanceListView(config: cfg, server: server)
                    }
                case .instance(let id):
                    if let inst = env.store.data.clientInstances.first(where: { $0.id == id }),
                       let cfg = env.store.data.clientConfigs.first(where: { $0.id == inst.clientConfigId }),
                       let server = env.store.data.servers.first(where: { $0.id == cfg.serverId }) {
                        InstanceDetailView(instance: inst, config: cfg, server: server)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("Help")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        attemptImport()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import from clipboard")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                ServerEditView()
            }
            .sheet(isPresented: $showingHelp) {
                HelpGuideView(mode: .help)
            }
            .onChange(of: env.pendingShowAddServer) { _, wantsAdd in
                if wantsAdd {
                    env.pendingShowAddServer = false
                    showingAdd = true
                }
            }
            .alert(item: $importAlert) { alert in
                switch alert {
                case .success(let name):
                    return Alert(
                        title: Text("Imported"),
                        message: Text("'\(name)' has been added."),
                        dismissButton: .default(Text("OK"))
                    )
                case .duplicate(let id, let name):
                    return Alert(
                        title: Text("Config already exists"),
                        message: Text("'\(name)' is already configured on this server."),
                        primaryButton: .default(Text("View Config")) {
                            path.append(NavTarget.config(id))
                        },
                        secondaryButton: .cancel(Text("OK"))
                    )
                case .error(let msg):
                    return Alert(
                        title: Text("Import failed"),
                        message: Text(msg),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    /// 从剪贴板读取 instance export JSON，按规则导入
    private func attemptImport() {
        guard let raw = UIPasteboard.general.string else {
            importAlert = .error("Clipboard is empty")
            return
        }
        let parsed: InstanceExport.Parsed
        do {
            parsed = try InstanceExport.decode(raw)
        } catch {
            importAlert = .error(error.localizedDescription)
            return
        }

        // 1) Server dedup：按 host 复用
        let server: Server
        if let existing = env.store.data.servers.first(where: { $0.host == parsed.serverRef.host }) {
            server = existing
        } else {
            let new = Server(name: parsed.serverRef.name, host: parsed.serverRef.host)
            env.store.upsertServer(new)
            env.registerServer(new)
            server = new
        }

        // 2) Config dedup：同 server 下同 qtunnelPort 视为同一配置
        if let existing = env.store.data.clientConfigs.first(where: {
            $0.serverId == server.id && $0.qtunnelPort == parsed.serverPort
        }) {
            importAlert = .duplicate(configId: existing.id, configName: existing.name)
            return
        }

        // 3) 创建 Config + Instance（默认 config name = server name；backendHost 固定 127.0.0.1）
        let cfg = ClientConfig(
            name: parsed.configName,
            serverId: server.id,
            qtunnelPort: parsed.serverPort,
            cryptoMethod: parsed.cryptoMethod,
            secret: parsed.password,
            backendPort: parsed.backendPort
        )
        env.store.upsertClientConfig(cfg)
        _ = env.createInstance(for: cfg)

        importAlert = .success(configName: cfg.name)
    }

    // MARK: - Sections

    @ViewBuilder
    private var serverSection: some View {
        if env.store.data.servers.isEmpty {
            VStack(spacing: DS.Spacing.l) {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "server.rack",
                    description: Text("Tap + to add your first qtunnel-server")
                )
                .listRowBackground(Color.clear)

                HelpButton(label: "What is Porta?", action: { showingHelp = true }, prominent: true)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } else {
            ForEach(env.store.data.servers) { server in
                NavigationLink(value: NavTarget.server(server.id)) {
                    ServerRow(server: server, state: env.serverState(for: server.id))
                }
                .swipeActions {
                    Button(role: .destructive) {
                        env.removeServer(server.id)
                        env.store.deleteServer(server.id)
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }

    @ViewBuilder
    private var homeInstancesSection: some View {
        let items = homeInstances
        if !items.isEmpty {
            Section("Instances") {
                ForEach(items) { item in
                    NavigationLink(value: NavTarget.instance(item.instance.id)) {
                        HomeInstanceRow(
                            instance: item.instance,
                            config: item.config,
                            server: item.server,
                            status: item.status,
                            localPort: item.localPort
                        )
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            env.instanceState(for: item.instance).stop()
                            env.store.deleteClientInstance(item.instance.id)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
    }

    /// 跨所有 server/config 扁平收集所有 instance。
    /// 状态/端口从 env.clientInstanceStates 实时读，避免依赖 Store 中未回写的字段。
    private var homeInstances: [HomeInstanceItem] {
        env.store.data.clientInstances.compactMap { inst in
            let state = env.clientInstanceStates[inst.id]
            let liveStatus = state?.status ?? inst.status
            let liveLocalPort = state?.localPort ?? inst.localPort
            guard let cfg = env.store.data.clientConfigs.first(where: { $0.id == inst.clientConfigId }),
                  let server = env.store.data.servers.first(where: { $0.id == cfg.serverId })
            else { return nil }
            return HomeInstanceItem(
                instance: inst,
                config: cfg,
                server: server,
                status: liveStatus,
                localPort: liveLocalPort
            )
        }
    }
}

private struct HomeInstanceItem: Identifiable {
    let instance: ClientInstance
    let config: ClientConfig
    let server: Server
    let status: ClientInstance.Status
    let localPort: Int
    var id: UUID { instance.id }
}

private struct HomeInstanceRow: View {
    let instance: ClientInstance
    let config: ClientConfig
    let server: Server
    let status: ClientInstance.Status
    let localPort: Int

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(config.name)
                    .font(DS.Font.headline)
                Text("\(server.name) · \(config.cryptoMethod.displayName)")
                    .font(DS.Font.caption1)
                    .foregroundStyle(DS.Color.labelSecondary)
                Text(portText)
                    .font(DS.Font.caption1)
                    .foregroundStyle(DS.Color.labelSecondary)
            }
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private var statusColor: Color {
        switch status {
        case .running: return DS.Color.statusUp
        case .failed: return DS.Color.statusDown
        default: return DS.Color.statusUnknown
        }
    }

    /// 有 local 端口才显示 local :<port>，否则直接显示 remote
    private var portText: String {
        if localPort > 0 {
            return "local :\(localPort) → \(server.host):\(config.qtunnelPort)"
        } else {
            return "\(server.host):\(config.qtunnelPort)"
        }
    }
}

private struct ServerRow: View {
    let server: Server
    let state: ServerState?

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(server.name).font(DS.Font.headline)
                Text(server.host).font(DS.Font.caption1).foregroundStyle(DS.Color.labelSecondary)
            }
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private var statusColor: Color {
        switch state?.status {
        case .up: return DS.Color.statusUp
        case .down: return DS.Color.statusDown
        default: return DS.Color.statusUnknown
        }
    }
}
