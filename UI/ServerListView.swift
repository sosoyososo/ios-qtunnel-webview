import SwiftUI

/// P1 — Server 列表
struct ServerListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var path = NavigationPath()
    @State private var showingAdd = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if env.store.data.servers.isEmpty {
                    ContentUnavailableView(
                        "No Servers",
                        systemImage: "server.rack",
                        description: Text("Tap + to add your first qtunnel-server")
                    )
                    .listRowBackground(Color.clear)
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
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                ServerEditView()
            }
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
                Text("\(server.host):\(server.port)").font(DS.Font.caption1).foregroundStyle(DS.Color.labelSecondary)
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