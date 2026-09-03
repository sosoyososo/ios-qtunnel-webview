import XCTest
@testable import Qtunnel
import Network

@MainActor
final class ServerStateTests: XCTestCase {

    func test_initialStatusIsUnknown() {
        let state = ServerState(server: Server(name: "S", host: "127.0.0.1", port: 9001))
        XCTAssertEqual(state.status, .unknown)
        XCTAssertNil(state.lastProbedAt)
    }

    func test_probeNowSetsUpStatus() async throws {
        // Start a mock TCP listener for the probe to succeed
        let mock = try await Self.startMockListener()
        defer { Task { mock.listener.cancel() } }

        let state = ServerState(server: Server(name: "S", host: "127.0.0.1", port: mock.port))
        await state.probeNow()
        XCTAssertEqual(state.status, .up)
        XCTAssertNotNil(state.lastProbedAt)
    }

    func test_probeNowSetsDownStatus() async {
        let state = ServerState(server: Server(name: "S", host: "127.0.0.1", port: 39999))
        await state.probeNow()
        XCTAssertEqual(state.status, .down)
    }

    // MARK: - Mock helper

    private struct MockListener {
        let listener: NWListener
        let port: Int
    }

    private static func startMockListener() async throws -> MockListener {
        try await withCheckedThrowingContinuation { continuation in
            let resumed = ResumeOnce()
            guard let listener = try? NWListener(using: .tcp, on: .any) else {
                continuation.resume(throwing: NSError(domain: "Test", code: 1))
                return
            }
            listener.stateUpdateHandler = { state in
                if case .ready = state {
                    if resumed.tryFire(), let p = listener.port {
                        continuation.resume(returning: MockListener(listener: listener, port: Int(p.rawValue)))
                    }
                }
            }
            listener.newConnectionHandler = { conn in conn.start(queue: .global()) }
            listener.start(queue: .global())
        }
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

/// 测试用"只触发一次"包装
private final class ResumeOnce {
    private var fired = false
    private let lock = NSLock()
    func tryFire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !fired else { return false }
        fired = true
        return true
    }
}
