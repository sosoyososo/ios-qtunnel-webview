import XCTest
@testable import Qtunnel
import Network

final class StatusProbeTests: XCTestCase {

    func test_returnsUp_whenPortOpen() async throws {
        let mock = try await Self.startMockListener()
        defer { Task { await mock.cancel() } }

        let status = await StatusProbe.probeOnce(host: "127.0.0.1", port: mock.port, timeout: .seconds(2))
        XCTAssertEqual(status, .up)
    }

    func test_returnsDown_whenPortClosed() async {
        // 选一个高 random 端口（假设无人占用；不保证 100% 隔离，但够用于 CI）
        let port = 39999
        let status = await StatusProbe.probeOnce(host: "127.0.0.1", port: port, timeout: .milliseconds(500))
        XCTAssertEqual(status, .down)
    }

    func test_returnsDown_onInvalidHost() async {
        // 无效 host 应 down
        let status = await StatusProbe.probeOnce(host: "256.256.256.256", port: 1, timeout: .milliseconds(500))
        XCTAssertEqual(status, .down)
    }

    // MARK: - Mock listener helper

    private static func startMockListener() async throws -> MockListener {
        try await withCheckedThrowingContinuation { continuation in
            let resumed = ResumeOnce()
            let listener = try? NWListener(using: .tcp, on: .any)
            guard let listener else {
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
            // 接受连接，**保持打开**（不 cancel），让 probe 看到 ready
            listener.newConnectionHandler = { conn in
                conn.start(queue: .global())
                // 让 conn 留在 listener 生命周期内；test 结束时 listener cancel 会连带关闭
                MockListener.activeConnections.append(conn)
            }
            listener.start(queue: .global())
        }
    }

    final class MockListener {
        let listener: NWListener
        let port: Int
        static var activeConnections: [NWConnection] = []

        init(listener: NWListener, port: Int) {
            self.listener = listener
            self.port = port
        }

        func cancel() {
            listener.cancel()
            for c in Self.activeConnections { c.cancel() }
            Self.activeConnections.removeAll()
        }
    }
}

/// 测试用的"只触发一次"包装
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
