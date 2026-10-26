import Network
import XCTest
@testable import Qtunnel

/// StatusProbe 的 up 语义 =「DNS 可解析」+「NWPath 网络可达」(spec 01 §4.4)
/// 离线环境（飞行模式 / 无网 CI）下 NWPath 必然 .unsatisfied，
/// 此时断言 .up 会产生与代码无关的假失败 → 先探测网络，不可达就跳过用例。
enum NetworkAvailability {

    /// 当前网络链路是否可达（与 StatusProbe 内部的 NWPath 判定同语义）
    static func isPathSatisfied() async -> Bool {
        await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            let monitor = NWPathMonitor()
            // NWPathMonitor 可能多次回调 pathUpdateHandler → 用 ResumeGuard 防重复 resume
            let once = ResumeGuard<Bool>()
            once.setContinuation(c)
            monitor.pathUpdateHandler = { path in
                once.resume(returning: path.status == .satisfied)
                monitor.cancel()
            }
            monitor.start(queue: DispatchQueue(label: "qtunnel.test.netpath"))
        }
    }

    /// 网络不可达时跳过当前用例
    static func skipUnlessNetworkAvailable() async throws {
        let up = await isPathSatisfied()
        try XCTSkipUnless(up, "需要网络可达（NWPath.satisfied）才能断言 status == .up")
    }
}
