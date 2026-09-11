import SwiftUI
import UIKit

/// P6 — 单 instance 详情 + Run/Test/Open WebView
struct InstanceDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let instance: ClientInstance
    let config: ClientConfig
    let server: Server

    @State private var testResult: TestResultBanner?
    @State private var webViewIds: [UUID] = []  // 当前 instance 的 webviews
    @State private var copiedLocal = false
    @State private var copiedServerCmd = false
    @State private var showingExportConfirm = false
    @State private var copiedExport = false

    enum TestResultBanner: Identifiable {
        case success(Int)
        case failure(String)
        var id: String { String(describing: self) }
    }

    var body: some View {
        let state = env.instanceState(for: instance)

        Form {
            Section("Status") {
                HStack {
                    Circle().fill(statusColor(state)).frame(width: 10, height: 10)
                    Text(statusText(state)).font(DS.Font.body)
                    Spacer()
                }
                LabeledRow("Local", value: localAddress.isEmpty ? "—" : localAddress)
                if !localAddress.isEmpty {
                    Button {
                        copyLocalAddress()
                    } label: {
                        Label(copiedLocal ? "Copied \(localAddress)" : "Copy \(localAddress)",
                              systemImage: copiedLocal ? "checkmark.circle.fill" : "doc.on.doc")
                    }
                    .foregroundStyle(DS.Color.accent)
                }
                LabeledRow("Remote", value: "\(server.host):\(config.tunnelPort) → :\(config.backendPort)")
                if let err = state.lastError {
                    LabeledRow("Error", value: err).foregroundStyle(DS.Color.statusDown)
                }
            }

            Section {
                Button {
                    Task {
                        let r = await state.test(clientConfig: config, server: server)
                        switch r {
                        case .success(let ms): testResult = .success(ms)
                        case .failure(let reason, _): testResult = .failure(reason)
                        }
                    }
                } label: {
                    Label("Test (5s)", systemImage: "bolt.horizontal.circle")
                }
                .disabled(state.status == .running)

                if state.status == .running {
                    Button(role: .destructive) {
                        state.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                } else {
                    Button {
                        Task {
                            await state.start(clientConfig: config, server: server)
                            // 持久化 localPort 到 store
                            var updated = instance
                            updated.localPort = env.instanceState(for: instance).actualLocalPort
                            if updated.localPort > 0 {
                                env.store.upsertClientInstance(updated)
                            }
                        }
                    } label: {
                        Label("Run", systemImage: "play.circle")
                    }
                    .disabled(state.status == .handshaking)
                }
            }

            Section("Config") {
                LabeledRow("Crypto", value: config.cryptoMethod.displayName)
                Button {
                    copyServerCmd()
                } label: {
                    Label(copiedServerCmd ? "Copied Server Cmd" : "Copy Server Cmd",
                          systemImage: copiedServerCmd ? "checkmark.circle.fill" : "terminal")
                }
                .foregroundStyle(DS.Color.accent)
            }

            Section("WebViews") {
                ForEach(webViewIds, id: \.self) { wvId in
                    if let wv = env.store.data.webViews.first(where: { $0.id == wvId }) {
                        NavigationLink {
                            WebViewCanvas(initialWebView: wv, config: config, instance: instance)
                        } label: {
                            Text("WebView #\(wv.indexInConfig)")
                        }
                        .disabled(state.status != .running)
                    }
                }
                Button {
                    let next = (webViewIds.count == 0 ? 1 : (webViewIds.count + 1))
                    let wv = WebViewState(clientInstanceId: instance.id, indexInConfig: next)
                    env.store.upsertWebView(wv)
                    webViewIds.append(wv.id)
                } label: {
                    Label("Open WebView", systemImage: "safari")
                }
                .disabled(state.status != .running)
            }

            Section("Share") {
                Button {
                    showingExportConfirm = true
                } label: {
                    Label(copiedExport ? "Exported" : "Export Config",
                          systemImage: copiedExport ? "checkmark.circle.fill" : "square.and.arrow.up")
                }
                .foregroundStyle(DS.Color.accent)
            }
        }
        .navigationTitle(instanceName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(instanceName)
                        .font(DS.Font.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("Instance Detail")
                        .font(DS.Font.caption2)
                        .foregroundStyle(DS.Color.labelSecondary)
                        .lineLimit(1)
                }
            }
        }
        .alert("Export contains plaintext password", isPresented: $showingExportConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Copy Anyway") {
                performExport()
            }
        } message: {
            Text("The exported JSON contains the password in plaintext. Do not share it with anyone you don't trust.")
        }
        .onAppear {
            webViewIds = env.store.data.webViews
                .filter { $0.clientInstanceId == instance.id }
                .sorted { $0.indexInConfig < $1.indexInConfig }
                .map(\.id)
        }
        .alert(item: $testResult) { r in
            switch r {
            case .success(let ms):
                return Alert(title: Text("Test passed"), message: Text("Latency: \(ms)ms"), dismissButton: .default(Text("OK")))
            case .failure(let reason):
                return Alert(title: Text("Test failed"), message: Text(reason), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func statusText(_ s: ClientInstanceState) -> String {
        switch s.status {
        case .idle: return "Idle"
        case .handshaking: return "Handshaking…"
        case .running: return "Running"
        case .failed: return "Failed"
        case .stopped: return "Stopped"
        }
    }

    private func statusColor(_ s: ClientInstanceState) -> Color {
        switch s.status {
        case .running: return DS.Color.statusUp
        case .failed: return DS.Color.statusDown
        default: return DS.Color.statusUnknown
        }
    }

    /// 本地隧道入口，例如 127.0.0.1:65043
    private var localAddress: String {
        instance.localPort > 0 ? "127.0.0.1:\(instance.localPort)" : ""
    }

    /// 显示用名：与 InstanceRow 命名规则一致（按在所属 config 的顺序编号）
    private var instanceName: String {
        let siblings = env.store.data.clientInstances.filter { $0.clientConfigId == instance.clientConfigId }
        if let idx = siblings.firstIndex(where: { $0.id == instance.id }) {
            return "instance #\(idx + 1)"
        }
        return "instance"
    }

    private func copyLocalAddress() {
        guard !localAddress.isEmpty else { return }
        UIPasteboard.general.string = localAddress
        copiedLocal = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            copiedLocal = false
        }
    }

    /// 生成与 ClientConfigEditView 一致的服务端启动命令并拷贝到剪贴板
    private func copyServerCmd() {
        let cmd = ServerCmd.build(
            listenPort: config.tunnelPort,
            backendHost: "127.0.0.1",
            backendPort: config.backendPort,
            crypto: config.cryptoMethod.cliValue,
            secret: config.secret
        )
        UIPasteboard.general.string = cmd
        copiedServerCmd = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            copiedServerCmd = false
        }
    }

    /// 导出当前 instance 的配置（JSON）到剪贴板
    private func performExport() {
        let json = InstanceExport.encode(instance: instance, config: config, server: server)
        UIPasteboard.general.string = json
        copiedExport = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            copiedExport = false
        }
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String
    init(_ label: String, value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack {
            Text(label).foregroundStyle(DS.Color.labelSecondary)
            Spacer()
            Text(value).font(DS.Font.body.monospaced())
        }
    }
}
