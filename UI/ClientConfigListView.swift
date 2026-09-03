import SwiftUI

/// P3 — 隶属于某 server 的 clientConfig 列表
struct ClientConfigListView: View {
    @Environment(AppEnvironment.self) private var env
    let server: Server

    @State private var showingAdd = false

    private var configs: [ClientConfig] {
        env.store.data.clientConfigs.filter { $0.serverId == server.id }
    }

    var body: some View {
        List {
            if configs.isEmpty {
                ContentUnavailableView(
                    "No Client Configs",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Tap + to add a clientConfig")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(configs) { cfg in
                    NavigationLink(value: cfg.id) {
                        ClientConfigRow(config: cfg)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            env.store.deleteClientConfig(cfg.id)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(server.name)
        .navigationDestination(for: UUID.self) { cfgId in
            if let cfg = env.store.data.clientConfigs.first(where: { $0.id == cfgId }) {
                ClientInstanceListView(config: cfg, server: server)
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
            ClientConfigEditView(server: server, config: nil)
        }
    }
}

private struct ClientConfigRow: View {
    let config: ClientConfig

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(config.name).font(DS.Font.headline)
            HStack(spacing: DS.Spacing.s) {
                Text(config.cryptoMethod.cliValue).font(DS.Font.caption1).foregroundStyle(DS.Color.accent)
                Text("•").foregroundStyle(DS.Color.labelSecondary)
                Text("\(config.backendHost):\(config.backendPort)")
                    .font(DS.Font.caption1).foregroundStyle(DS.Color.labelSecondary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
