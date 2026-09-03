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
    private var activeForwarders: [ObjectIdentifier: TCPForwarder] = [:]
    private var heartbeat: Heartbeat?
    private var tunnelReadyContinuation: CheckedContinuation<Void, Never>?

    var localPort: Int { instance.localPort }

    init(instance: ClientInstance) {
        self.instance = instance
        self.status = instance.status
    }

    /// 启动长连接（Run）
    func start(clientConfig: ClientConfig, server: Server) async {
        guard status == .idle || status == .stopped else {
            Log.debug("ClientInstanceState", "start ignored, status=\(status)")
            return
        }
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
        // 注意：localPort 持久化在 P7 UI 层处理（这里仅修改内存中的 instance）

        // 3. tunnel
        let tunnel = TunnelConnection(host: server.host, port: server.port, cipher: cipher)
        self.tunnel = tunnel

        // 等待 tunnel ready（用 continuation）
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.tunnelReadyContinuation = cont
            tunnel.onState = { [weak self] state in
                guard let self else { return }
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self.status = .running
                        // 启 heartbeat
                        let hb = Heartbeat(connection: tunnel)
                        Task { await hb.start() }
                        self.heartbeat = hb
                        // resume 启动 continuation
                        self.tunnelReadyContinuation?.resume()
                        self.tunnelReadyContinuation = nil
                    case .failed(let err):
                        self.lastError = "tunnel failed: \(err)"
                        self.status = .failed
                        self.tunnelReadyContinuation?.resume()
                        self.tunnelReadyContinuation = nil
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
        let tunnel = TunnelConnection(host: server.host, port: server.port, cipher: cipher)
        let ready = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            tunnel.onState = { state in
                switch state {
                case .ready: cont.resume(returning: true)
                case .failed: cont.resume(returning: false)
                default: break
                }
            }
            tunnel.connect()
            // 5s timeout
            Task {
                try? await Task.sleep(for: .seconds(5))
                cont.resume(returning: false)
            }
        }
        // 关闭
        tunnel.disconnect()
        await listener.stop()

        let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
        return ready ? .success(latencyMs: latencyMs) : .failure(reason: "timeout or connect failed", latencyMs: latencyMs)
    }

    func stop() {
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
        status = .stopped
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
