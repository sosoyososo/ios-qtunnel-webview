import SwiftUI

/// P1 — Server 列表
struct ServerListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
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
                        NavigationLink(value: server.id) {
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
            .navigationDestination(for: UUID.self) { serverId in
                if let server = env.store.data.servers.first(where: { $0.id == serverId }) {
                    ClientConfigListView(server: server)
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
