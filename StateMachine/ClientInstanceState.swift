import Foundation
import Observation
import Network

/// ClientInstance 运行时状态机 — spec 01 §3.3
/// 实例只负责本地监听端口；每个被接受的本地连接独享一条到 qtunnel-server
/// 的加密隧道（one local conn ⇄ one tunnel ⇄ one backend conn）。
/// 单条隧道故障不会让整个实例停止 —— 实例随 listener 生命周期走。
@Observable
@MainActor
final class ClientInstanceState {

    let instance: ClientInstance
    private(set) var status: ClientInstance.Status = .idle
    private(set) var lastError: String?

    private var listener: LocalListener?
    private var activeConfig: ClientConfig?
    private var activeServer: Server?
    private(set) var actualLocalPort: Int = 0   // 由 listener.bind 提供（与 instance.localPort 区分）
    private var activeForwarders: [ObjectIdentifier: TCPForwarder] = [:]

    var localPort: Int { actualLocalPort > 0 ? actualLocalPort : instance.localPort }

    init(instance: ClientInstance) {
        self.instance = instance
        self.status = instance.status
    }

    /// 启动本地监听（Run）。不预建隧道 —— 每个新本地连接按需建隧道。
    func start(clientConfig: ClientConfig, server: Server) async {
        // 允许从 idle/stopped/failed 启动；仅 running/handshaking 时拒绝重复启动
        guard status != .running, status != .handshaking else {
            Log.debug("ClientInstanceState", "start ignored, status=\(status)")
            return
        }
        teardownNetwork()   // 清理上一次运行遗留的 listener/forwarders
        actualLocalPort = 0
        lastError = nil
        activeConfig = clientConfig
        activeServer = server
        status = .handshaking

        let listener = LocalListener()
        let port: Int
        do {
            port = try await listener.start { [weak self] conn in
                Task { @MainActor in
                    self?.handleLocalConnection(conn)
                }
            }
        } catch {
            lastError = "listen failed: \(error)"
            activeConfig = nil
            activeServer = nil
            status = .failed
            return
        }
        self.listener = listener
        actualLocalPort = port
        status = .running
        Log.info("ClientInstanceState", "listening on 127.0.0.1:\(port)")
    }

    /// Test 模式：5s timeout，成功/失败都关闭
    func test(clientConfig: ClientConfig, server: Server) async -> TestResult {
        let start = Date()
        let cipher = CipherFactory.make(method: clientConfig.cryptoMethod, secret: clientConfig.secret)

        // 起 listener
        let listener = LocalListener()
        let port: Int
        do {
            port = try await listener.start { _ in /* ignore */ }
        } catch {
            await listener.stop()
            return .failure(reason: "listen failed: \(error)", latencyMs: 0)
        }

        // 连接 tunnel
        let tunnel = TunnelConnection(host: server.host, port: clientConfig.qtunnelPort, cipher: cipher)
        let resumeG = ResumeGuard<Bool>()
        let ready = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            resumeG.setContinuation(cont)
            tunnel.onState = { state in
                switch state {
                case .ready: resumeG.resume(returning: true)
                case .failed: resumeG.resume(returning: false)
                default: break
                }
            }
            tunnel.connect()
            // 5s timeout
            Task {
                try? await Task.sleep(for: .seconds(5))
                resumeG.resume(returning: false)
            }
        }
        // 关闭
        tunnel.disconnect()
        await listener.stop()

        let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
        return ready ? .success(latencyMs: latencyMs) : .failure(reason: "timeout or connect failed", latencyMs: latencyMs)
    }

    func stop() {
        teardownNetwork()
        status = .stopped
    }

    /// 清理运行期资源（listener + 各 forwarder），不改 status
    private func teardownNetwork() {
        if let l = listener {
            listener = nil
            Task { await l.stop() }
        }
        for f in activeForwarders.values { f.stop() }
        activeForwarders.removeAll()
        activeConfig = nil
        activeServer = nil
    }

    // MARK: - Local connection handler

    private func handleLocalConnection(_ conn: NWConnection) {
        guard let cfg = activeConfig, let server = activeServer else {
            conn.cancel()
            return
        }
        // 每条本地连接 = 新 cipher + 新隧道（服务端 transport 也按连接 NewCipher）
        let cipher = CipherFactory.make(method: cfg.cryptoMethod, secret: cfg.secret)
        let tunnel = TunnelConnection(host: server.host, port: cfg.qtunnelPort, cipher: cipher)
        let key = ObjectIdentifier(conn)
        let forwarder = TCPForwarder(local: conn, tunnel: tunnel) { [weak self] in
            Task { @MainActor in
                self?.activeForwarders.removeValue(forKey: key)
            }
        }
        activeForwarders[key] = forwarder
        forwarder.start()
    }

    // MARK: - Test result

    enum TestResult: Sendable {
        case success(latencyMs: Int)
        case failure(reason: String, latencyMs: Int)
    }
}
