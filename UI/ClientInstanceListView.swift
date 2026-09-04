import SwiftUI

/// P5 — 隶属于某 clientConfig 的 instance 列表
struct ClientInstanceListView: View {
    @Environment(AppEnvironment.self) private var env
    let config: ClientConfig
    let server: Server

    private var instances: [ClientInstance] {
        env.store.data.clientInstances.filter { $0.clientConfigId == config.id }
    }

    var body: some View {
        Group {
            if instances.isEmpty {
                emptyState
            } else {
                instanceList
            }
        }
        .navigationTitle(config.name)
        // navigationDestination 已上移到 ServerListView 统一处理
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    _ = env.createInstance(for: config)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.l) {
            Image(systemName: "bolt.circle")
                .font(.system(size: 48))
                .foregroundStyle(DS.Color.labelSecondary)
            Text("No instances yet")
                .font(DS.Font.headline)
            Text("Tap + to create the first client instance")
                .font(DS.Font.caption1)
                .foregroundStyle(DS.Color.labelSecondary)
            Button {
                let inst = env.createInstance(for: config)
                print("[ClientInstanceList] created \(inst.id)")
            } label: {
                Label("Add Instance", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Color.bgGrouped)
    }

    private var instanceList: some View {
        List {
            ForEach(instances) { inst in
                NavigationLink(value: NavTarget.instance(inst.id)) {
                    InstanceRow(
                        instance: inst,
                        state: env.instanceState(for: inst),
                        indexNumber: (instances.firstIndex(of: inst) ?? 0) + 1
                    )
                }
                .swipeActions {
                    Button(role: .destructive) {
                        env.instanceState(for: inst).stop()
                        env.store.deleteClientInstance(inst.id)
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }
}

private struct InstanceRow: View {
    let instance: ClientInstance
    let state: ClientInstanceState
    let indexNumber: Int

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("instance #\(indexNumber)")
                    .font(DS.Font.headline)
                Text(statusText)
                    .font(DS.Font.caption1)
                    .foregroundStyle(DS.Color.labelSecondary)
            }
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private var statusText: String {
        switch state.status {
        case .idle: return instance.localPort == 0 ? "idle" : "local :\(instance.localPort) • idle"
        case .handshaking: return "handshaking…"
        case .running: return "local :\(instance.localPort) • running"
        case .failed: return "failed" + (state.lastError.map { " • \($0)" } ?? "")
        case .stopped: return "stopped"
        }
    }

    private var statusColor: Color {
        switch state.status {
        case .running: return DS.Color.statusUp
        case .failed: return DS.Color.statusDown
        default: return DS.Color.statusUnknown
        }
    }
}
