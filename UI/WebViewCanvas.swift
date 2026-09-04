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

/// 单 webview pane：navigation bar (back/home/close) + WKWebView
private struct WebViewPane: View {
    @Environment(AppEnvironment.self) private var env
    let webView: WebViewState
    let instance: ClientInstance
    let config: ClientConfig

    @StateObject private var coordinator = WebViewCoordinator()

    private var homeURL: URL? {
        guard instance.localPort > 0 else { return nil }
        return URL(string: "http://127.0.0.1:\(instance.localPort)/")
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            if let url = homeURL {
                TunneledWebView(url: url, coordinator: coordinator)
            } else {
                ContentUnavailableView(
                    "Tunnel Not Running",
                    systemImage: "wifi.slash",
                    description: Text("Start the client first (Run)")
                )
            }
        }
        .onChange(of: instance.localPort) { _, _ in
            // tunnel 启动后把 webview 重定向到 home
            coordinator.load(homeURL)
        }
    }

    private var navBar: some View {
        HStack(spacing: DS.Spacing.m) {
            Text("\(config.name)[\(webView.indexInConfig)]")
                .font(DS.Font.headline)
                .lineLimit(1)
            Spacer()
            Button {
                coordinator.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!coordinator.canGoBack)

            Button {
                coordinator.load(homeURL)
            } label: {
                Image(systemName: "house.fill")
            }
            .disabled(homeURL == nil)

            Button {
                coordinator.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!coordinator.canGoForward)

            Button(role: .destructive) {
                env.store.deleteWebView(webView.id)
            } label: {
                Image(systemName: "xmark")
            }
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(DS.Color.bgSecondary)
    }
}

/// 把 WKWebView 的 canGoBack/canGoForward 状态暴露给 SwiftUI
@MainActor
final class WebViewCoordinator: NSObject, ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false

    weak var webView: WKWebView?

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func load(_ url: URL?) {
        guard let url else { return }
        webView?.load(URLRequest(url: url))
    }

    fileprivate func attach(_ webView: WKWebView) {
        self.webView = webView
        webView.addObserver(self, forKeyPath: "canGoBack", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "canGoForward", options: .new, context: nil)
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    fileprivate func detach() {
        guard let wv = webView else { return }
        wv.removeObserver(self, forKeyPath: "canGoBack")
        wv.removeObserver(self, forKeyPath: "canGoForward")
        webView = nil
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard let wv = webView else { return }
        if keyPath == "canGoBack" { canGoBack = wv.canGoBack }
        if keyPath == "canGoForward" { canGoForward = wv.canGoForward }
    }

    deinit {
        if let wv = webView {
            wv.removeObserver(self, forKeyPath: "canGoBack")
            wv.removeObserver(self, forKeyPath: "canGoForward")
        }
    }
}

/// WKWebView 包装
private struct TunneledWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var coordinator: WebViewCoordinator

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        coordinator.attach(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 仅在 url 变化时重新加载
        if webView.url == nil {
            webView.load(URLRequest(url: url))
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: ()) {
        // 实际清理由 Coordinator.detach 负责
    }
}
