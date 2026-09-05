import Foundation
import Observation
import Network

/// ClientInstance 运行时状态机 — spec 01 §3.3
/// 持有 TunnelConnection + LocalListener + TCPForwarder + Heartbeat，
/// 驱动 start/stop 流程；UI 仅观察 status 字段
@Observable
@MainActor
final class ClientInstanceState {

    let instance: ClientInstance
    private(set) var status: ClientInstance.Status = .idle
    private(set) var lastError: String?

    private var tunnel: TunnelConnection?
    private var listener: LocalListener?
    private(set) var actualLocalPort: Int = 0   // 由 listener.bind 提供（与 instance.localPort 区分）
    private var activeForwarders: [ObjectIdentifier: TCPForwarder] = [:]
    private var heartbeat: Heartbeat?
    private var timeoutTask: Task<Void, Never>?
    private var tunnelReadyContinuation: CheckedContinuation<Void, Never>?

    var localPort: Int { actualLocalPort > 0 ? actualLocalPort : instance.localPort }

    init(instance: ClientInstance) {
        self.instance = instance
        self.status = instance.status
    }

    /// 启动长连接（Run）
    func start(clientConfig: ClientConfig, server: Server) async {
        // 允许从 idle/stopped/failed 启动；仅 running/handshaking 时拒绝重复启动
        guard status != .running, status != .handshaking else {
            Log.debug("ClientInstanceState", "start ignored, status=\(status)")
            return
        }
        teardownNetwork()   // 清理上一次失败/停止运行遗留的 listener/tunnel
        actualLocalPort = 0
        status = .handshaking
        lastError = nil

        // 1. cipher
        let cipher = CipherFactory.make(method: clientConfig.cryptoMethod, secret: clientConfig.secret)

        // 2. 本地 listener
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
            status = .failed
            return
        }
        self.listener = listener
        actualLocalPort = port  // 记录实际监听端口

        // 3. tunnel
        let tunnel = TunnelConnection(host: server.host, port: clientConfig.qtunnelPort, cipher: cipher)
        self.tunnel = tunnel

        // 等待 tunnel ready（用 continuation + ResumeGuard 防止 double-resume）
        let startGuard = ResumeGuard<Void>()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            startGuard.setContinuation(cont)
            tunnel.onState = { [weak self] state in
                guard let self else { return }
                Task { @MainActor in
                    // 只处理本次运行的 tunnel 事件；旧连接残留回调不干扰新运行
                    guard self.tunnel === tunnel else { return }
                    switch state {
                    case .ready:
                        // 超时已标 failed 后才到的 ready 忽略，避免状态被回卷
                        guard self.status == .handshaking else { return }
                        self.timeoutTask?.cancel()
                        self.status = .running
                        let hb = Heartbeat(connection: tunnel)
                        Task { await hb.start() }
                        self.heartbeat = hb
                        startGuard.resume(returning: ())
                    case .failed(let err):
                        self.timeoutTask?.cancel()
                        self.lastError = "tunnel failed: \(err)"
                        self.status = .failed
                        startGuard.resume(returning: ())
                    case .closed:
                        if self.status == .running {
                            self.status = .stopped
                        }
                    default:
                        break
                    }
                }
            }
            tunnel.connect()
            // 启动超时 fallback：10s 未 ready → 失败，避免 UI 无限停留在 Handshaking
            timeoutTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(10))
                guard self.status == .handshaking else { return }
                self.lastError = "connect timeout: server \(server.host):\(clientConfig.qtunnelPort) unreachable in 10s"
                self.status = .failed
                startGuard.resume(returning: ())
            }
        }

        // localPort 在 P7 持久化
        Log.info("ClientInstanceState", "running on local port \(port)")
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

    /// 清理运行期资源（timeout / heartbeat / tunnel / listener / forwarder），不改 status
    private func teardownNetwork() {
        timeoutTask?.cancel()
        timeoutTask = nil
        if let hb = heartbeat {
            heartbeat = nil
            Task { await hb.stop() }
        }
        tunnel?.disconnect()
        tunnel = nil
        if let l = listener {
            listener = nil
            Task { await l.stop() }
        }
        for f in activeForwarders.values { f.stop() }
        activeForwarders.removeAll()
    }

    // MARK: - Local connection handler

    private func handleLocalConnection(_ conn: NWConnection) {
        guard let tunnel else {
            conn.cancel()
            return
        }
        let forwarder = TCPForwarder(local: conn, tunnel: tunnel)
        activeForwarders[ObjectIdentifier(conn)] = forwarder
        forwarder.start()
    }

    // MARK: - Test result

    enum TestResult: Sendable {
        case success(latencyMs: Int)
        case failure(reason: String, latencyMs: Int)
    }
}
