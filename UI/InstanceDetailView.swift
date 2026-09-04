import SwiftUI

/// P6 — 单 instance 详情 + Run/Test/Open WebView
struct InstanceDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let instance: ClientInstance
    let config: ClientConfig
    let server: Server

    @State private var testResult: TestResultBanner?
    @State private var webViewIds: [UUID] = []  // 当前 instance 的 webviews

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
                LabeledRow("Local", value: instance.localPort > 0 ? "127.0.0.1:\(instance.localPort)" : "—")
                LabeledRow("Remote", value: "\(server.host):\(config.qtunnelPort)")
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

            Section("WebViews") {
                ForEach(webViewIds, id: \.self) { wvId in
                    if let wv = env.store.data.webViews.first(where: { $0.id == wvId }) {
                        NavigationLink {
                            WebViewCanvas(initialWebView: wv, config: config, instance: instance)
                        } label: {
                            Text("WebView #\(wv.indexInConfig)")
                        }
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
        }
        .navigationTitle("instance")
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
