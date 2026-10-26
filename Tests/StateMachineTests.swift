import XCTest
@testable import Qtunnel

@MainActor
final class ServerStateTests: XCTestCase {

    func test_initialStatusIsUnknown() {
        let state = ServerState(server: Server(name: "S", host: "127.0.0.1"))
        XCTAssertEqual(state.status, .unknown)
        XCTAssertNil(state.lastProbedAt)
    }

    func test_probeNowSetsUpStatus() async throws {
        // Server 不带端口 → probe 语义 = DNS 可解析 + NWPath 网络可达
        try await NetworkAvailability.skipUnlessNetworkAvailable()
        let state = ServerState(server: Server(name: "S", host: "127.0.0.1"))
        await state.probeNow()
        XCTAssertEqual(state.status, .up)
        XCTAssertNotNil(state.lastProbedAt)
    }

    func test_probeNowSetsDownStatus() async {
        // .invalid 是 RFC 2606 保留 TLD,保证解析失败
        let state = ServerState(server: Server(name: "S", host: "qtunnel-nonexistent-host.invalid"))
        await state.probeNow()
        XCTAssertEqual(state.status, .down)
    }
}

@MainActor
final class WebViewStateMachineTests: XCTestCase {

    func test_initialStatus_pending() {
        let wv = WebViewState(clientInstanceId: UUID(), indexInConfig: 1)
        let m = WebViewStateMachine(webView: wv)
        XCTAssertEqual(m.status, .pending)
    }

    func test_initialStatus_focusedWhenFocused() {
        let wv = WebViewState(clientInstanceId: UUID(), indexInConfig: 1, isFocused: true)
        let m = WebViewStateMachine(webView: wv)
        XCTAssertEqual(m.status, .focused)
    }

    func test_focusAndHide() {
        let wv = WebViewState(clientInstanceId: UUID(), indexInConfig: 1)
        let m = WebViewStateMachine(webView: wv)
        m.markLoading()
        m.markLoaded()
        m.focus()
        XCTAssertEqual(m.status, .focused)
        XCTAssertTrue(m.webView.isFocused)
        m.hide()
        XCTAssertEqual(m.status, .hidden)
        XCTAssertFalse(m.webView.isFocused)
    }
}
