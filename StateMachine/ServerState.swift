import Foundation
import Observation

/// Server 在线状态 — spec 01 §3.1
/// 持有 StatusProbe（DNS-based），向 UI 暴露当前状态
@Observable
@MainActor
final class ServerState {

    let server: Server
    private(set) var status: Status = .unknown
    private(set) var lastProbedAt: Date?

    private var probe: StatusProbe?

    enum Status: Sendable, Equatable {
        case unknown, up, down
    }

    init(server: Server) {
        self.server = server
    }

    /// 启动周期 probe
    func startProbing() {
        stopProbing()
        let probe = StatusProbe(host: server.host)
        self.probe = probe
        Task { [weak self] in
            await probe.start { [weak self] s in
                Task { @MainActor in
                    self?.applyStatus(s == .up ? .up : .down)
                }
            }
        }
    }

    func stopProbing() {
        let p = probe
        probe = nil
        if let p {
            Task { await p.stop() }
        }
    }

    /// 单次 probe（手动刷新）
    func probeNow() async {
        let s = await StatusProbe.probeOnce(host: server.host)
        applyStatus(s == .up ? .up : .down)
    }

    private func applyStatus(_ s: Status) {
        status = s
        lastProbedAt = Date()
    }
}
