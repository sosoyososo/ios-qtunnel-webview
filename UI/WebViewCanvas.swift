import SwiftUI
import WebKit

/// P7 — 多 webview 容器
/// iPhone：tab strip 切换，单 webview 全屏
/// iPad：自由浮动（占位，未来扩展）
struct WebViewCanvas: View {
    @Environment(AppEnvironment.self) private var env
    let initialWebView: WebViewState
    let config: ClientConfig
    let instance: ClientInstance

    @State private var webViewIds: [UUID] = []
    @State private var focusedId: UUID?

    private var allWebViews: [WebViewState] {
        env.store.data.webViews
            .filter { $0.clientInstanceId == instance.id }
            .sorted { $0.indexInConfig < $1.indexInConfig }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let id = focusedId, let wv = allWebViews.first(where: { $0.id == id }) {
                WebViewPane(webView: wv, instance: instance, config: config)
            } else {
                ContentUnavailableView(
                    "No WebView",
                    systemImage: "safari",
                    description: Text("Tap + to open")
                )
                .frame(maxHeight: .infinity)
            }
            tabStrip
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addWebView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            if webViewIds.isEmpty {
                webViewIds = allWebViews.map(\.id)
                focusedId = initialWebView.id
            } else {
                focusedId = initialWebView.id
            }
        }
    }

    private var titleText: String {
        let n = config.name
        if let id = focusedId, let wv = allWebViews.first(where: { $0.id == id }) {
            return "\(n)[\(wv.indexInConfig)]"
        }
        return n
    }

    private var tabStrip: some View {
        HStack(spacing: DS.Spacing.s) {
            ForEach(webViewIds, id: \.self) { id in
                if let wv = allWebViews.first(where: { $0.id == id }) {
                    Button {
                        focusedId = id
                    } label: {
                        Text("\(wv.indexInConfig)")
                            .font(DS.Font.caption1)
                            .frame(width: 32, height: 28)
                            .background(id == focusedId ? DS.Color.accent : DS.Color.bgSecondary)
                            .foregroundStyle(id == focusedId ? .white : DS.Color.labelPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.thumb))
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            closeWebView(id)
                        } label: { Label("Close", systemImage: "xmark") }
                    }
                }
            }
            Button {
                addWebView()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 32, height: 28)
                    .background(DS.Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.thumb))
            }
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(DS.Color.bgGrouped)
    }

    private func addWebView() {
        let next = (allWebViews.map(\.indexInConfig).max() ?? 0) + 1
        let wv = WebViewState(clientInstanceId: instance.id, indexInConfig: next)
        env.store.upsertWebView(wv)
        webViewIds.append(wv.id)
        focusedId = wv.id
    }

    private func closeWebView(_ id: UUID) {
        webViewIds.removeAll { $0 == id }
        if focusedId == id {
            focusedId = webViewIds.first
        }
        env.store.deleteWebView(id)
    }
}

/// 单 webview pane：title bar + WKWebView
private struct WebViewPane: View {
    @Environment(AppEnvironment.self) private var env
    let webView: WebViewState
    let instance: ClientInstance
    let config: ClientConfig

    private var homeURL: URL? {
        guard instance.localPort > 0 else { return nil }
        return URL(string: "http://127.0.0.1:\(instance.localPort)/")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(config.name)[\(webView.indexInConfig)]")
                    .font(DS.Font.headline)
                Spacer()
                Button {
                    raiseZ()
                } label: { Image(systemName: "arrow.up") }
                Button {
                    lowerZ()
                } label: { Image(systemName: "arrow.down") }
                Button(role: .destructive) {
                    env.store.deleteWebView(webView.id)
                } label: { Image(systemName: "xmark") }
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.s)
            .background(DS.Color.bgSecondary)

            if let url = homeURL {
                TunneledWebView(url: url)
            } else {
                ContentUnavailableView(
                    "Tunnel Not Running",
                    systemImage: "wifi.slash",
                    description: Text("Start the client first (Run)")
                )
            }
        }
    }

    private func raiseZ() {
        var wv = webView
        wv.isFocused = true
        env.store.upsertWebView(wv)
    }

    private func lowerZ() {
        var wv = webView
        wv.isFocused = false
        env.store.upsertWebView(wv)
    }
}

/// WKWebView 包装
private struct TunneledWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let req = URLRequest(url: url)
        if webView.url != url {
            webView.load(req)
        }
    }
}
