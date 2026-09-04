import Foundation
import Network
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Server reachability probe — spec 01 §4.4
/// Server 不带端口 → 用 DNS 解析 + NWPath 综合判断
/// 「能解析 + 网络可达」视为 up
actor StatusProbe {

    enum Status: Sendable, Equatable {
        case up
        case down
    }

    private(set) var lastStatus: Status?
    private var task: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?

    let host: String
    let interval: Duration

    init(
        host: String,
        interval: Duration = .seconds(10)
    ) {
        self.host = host
        self.interval = interval
    }

    /// 启动周期 probe；每次状态变化通过 onUpdate 回调
    func start(onUpdate: @escaping @Sendable (Status) -> Void) {
        stop()
        let host = self.host
        let interval = self.interval

        let monitor = NWPathMonitor()
        let pathQueue = DispatchQueue(label: "StatusProbe.path")
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { [weak self] in
                guard let self else { return }
                let reachable = path.status == .satisfied
                let resolved = await Self.resolveDNS(host: host)
                let status: Status = (reachable && resolved) ? .up : .down
                await self.setLastStatus(status)
                onUpdate(status)
            }
        }
        monitor.start(queue: pathQueue)
        self.pathMonitor = monitor

        task = Task { [weak self] in
            while !Task.isCancelled {
                let status = await Self.probeOnce(host: host)
                await self?.setLastStatus(status)
                onUpdate(status)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    private func setLastStatus(_ status: Status) {
        lastStatus = status
    }

    /// 单次 probe；公开便于测试
    static func probeOnce(host: String) async -> Status {
        let resolved = await resolveDNS(host: host)
        guard resolved else { return .down }
        let pathOK = await currentPathUp()
        return pathOK ? .up : .down
    }

    // MARK: - DNS resolve via getaddrinfo

    static func resolveDNS(host: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let ok = dnsResolve(host: host)
                continuation.resume(returning: ok)
            }
        }
    }

    private static func dnsResolve(host: String) -> Bool {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        let err = getaddrinfo(host, nil, &hints, &result)
        defer { freeaddrinfo(result) }
        return err == 0
    }

    // MARK: - NWPath up?

    private static func currentPathUp() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "StatusProbe.pathOnce")
            monitor.pathUpdateHandler = { path in
                let ok = path.status == .satisfied
                monitor.cancel()
                continuation.resume(returning: ok)
            }
            monitor.start(queue: queue)
        }
    }
}
