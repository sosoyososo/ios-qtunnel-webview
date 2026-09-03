import Foundation
import Observation

/// WebView 状态机 — spec 01 §3.4
/// UI 层（P7）持有实际的 WKWebView；这里只跟踪 status 字段
@Observable
@MainActor
final class WebViewStateMachine {

    var webView: WebViewState
    private(set) var status: Status = .pending

    enum Status: Sendable {
        case pending, loading, loaded, hidden, focused
    }

    init(webView: WebViewState) {
        self.webView = webView
        if webView.isFocused {
            status = .focused
        }
    }

    func markLoading() { status = .loading }
    func markLoaded() { status = .loaded }

    func focus() {
        status = .focused
        webView.isFocused = true
    }

    func hide() {
        status = .hidden
        webView.isFocused = false
    }
}
