import XCTest
@testable import Qtunnel

/// StatusProbe 语义(spec 01 §4.4 / 决策 5):Server 不带端口 →
/// 「DNS 可解析 + NWPath 网络可达」才视为 up。端口探测已移除。
final class StatusProbeTests: XCTestCase {

    func test_returnsUp_forResolvableHost() async throws {
        try await NetworkAvailability.skipUnlessNetworkAvailable()
        let status = await StatusProbe.probeOnce(host: "localhost")
        XCTAssertEqual(status, .up)
    }

    func test_returnsUp_forLoopbackIP() async throws {
        try await NetworkAvailability.skipUnlessNetworkAvailable()
        let status = await StatusProbe.probeOnce(host: "127.0.0.1")
        XCTAssertEqual(status, .up)
    }

    func test_returnsDown_whenHostDoesNotResolve() async {
        // .invalid 是 RFC 2606 保留 TLD,保证永远解析失败
        let status = await StatusProbe.probeOnce(host: "qtunnel-nonexistent-host.invalid")
        XCTAssertEqual(status, .down)
    }
}
