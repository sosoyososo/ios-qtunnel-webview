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
        List {
            if instances.isEmpty {
                // 自动创建第一个 instance（决策：每 config 默认 1）
                Color.clear.frame(height: 0)
                    .onAppear { _ = env.createInstance(for: config) }
            }
            instancesContent
        }
        .listStyle(.insetGrouped)
        .navigationTitle(config.name)
        .navigationDestination(for: UUID.self) { instanceId in
            if let inst = env.store.data.clientInstances.first(where: { $0.id == instanceId }) {
                InstanceDetailView(instance: inst, config: config, server: server)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let inst = env.createInstance(for: config)
                    _ = inst
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            // 第一次进入时如果没有 instance，自动创建
            if env.store.data.clientInstances.filter({ $0.clientConfigId == config.id }).isEmpty {
                _ = env.createInstance(for: config)
            }
        }
    }

    @ViewBuilder
    private var instancesContent: some View {
        let siblings = env.store.data.clientInstances
            .filter { $0.clientConfigId == config.id }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        ForEach(siblings) { inst in
            NavigationLink(value: inst.id) {
                InstanceRow(
                    instance: inst,
                    state: env.instanceState(for: inst),
                    indexNumber: (siblings.firstIndex(of: inst) ?? 0) + 1
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
