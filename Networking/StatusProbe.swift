import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// TCP connect probe — spec 01 §4.4
/// 不走加密路径；每 5s probe 一次确认 server 进程存活
/// 用 POSIX socket 直连 + poll() 等待可写
actor StatusProbe {

    enum Status: Sendable, Equatable {
        case up
        case down
    }

    private(set) var lastStatus: Status?
    private var task: Task<Void, Never>?

    let host: String
    let port: Int
    let interval: Duration
    let timeout: Duration

    init(
        host: String,
        port: Int,
        interval: Duration = .seconds(5),
        timeout: Duration = .seconds(1)
    ) {
        self.host = host
        self.port = port
        self.interval = interval
        self.timeout = timeout
    }

    /// 启动周期 probe；每次状态变化通过 onUpdate 回调
    func start(onUpdate: @escaping @Sendable (Status) -> Void) {
        stop()
        let host = self.host, port = self.port, interval = self.interval, timeout = self.timeout
        task = Task { [weak self] in
            while !Task.isCancelled {
                let status = await Self.probeOnce(host: host, port: port, timeout: timeout)
                await self?.setLastStatus(status)
                onUpdate(status)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func setLastStatus(_ status: Status) {
        lastStatus = status
    }

    /// 单次 probe；公开便于测试
    static func probeOnce(host: String, port: Int, timeout: Duration) async -> Status {
        let timeoutSec = Double(timeout.components.seconds)
        let timeoutMs = Int32(timeoutSec * 1000.0)
        return await withCheckedContinuation { continuation in
            let resumed = ResumeGuard(continuation: continuation)
            DispatchQueue.global(qos: .utility).async {
                let status = tcpConnect(host: host, port: UInt16(port), timeoutMs: timeoutMs)
                resumed.tryResume(status)
            }
        }
    }

    // MARK: - POSIX TCP connect with timeout (uses poll)

    private static func tcpConnect(host: String, port: UInt16, timeoutMs: Int32) -> Status {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?
        let portStr = String(port)
        let err = getaddrinfo(host, portStr, &hints, &result)
        guard err == 0, let head = result else { return .down }
        defer { freeaddrinfo(result) }

        let ai = head.pointee
        let fd = socket(ai.ai_family, ai.ai_socktype, ai.ai_protocol)
        guard fd >= 0 else { return .down }
        defer { close(fd) }

        // non-blocking
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let rc = connect(fd, ai.ai_addr, ai.ai_addrlen)
        if rc == 0 { return .up }
        if errno != EINPROGRESS { return .down }

        // poll() 等可写
        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let pollResult = poll(&pfd, 1, timeoutMs)
        if pollResult <= 0 { return .down }

        // 检查 SO_ERROR
        var soErr: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        if getsockopt(fd, SOL_SOCKET, SO_ERROR, &soErr, &len) != 0 || soErr != 0 {
            return .down
        }
        return .up
    }
}

/// 防止 continuation 多次 resume
private final class ResumeGuard: @unchecked Sendable {
    private var cont: CheckedContinuation<StatusProbe.Status, Never>?
    private let lock = NSLock()

    init(continuation: CheckedContinuation<StatusProbe.Status, Never>) {
        self.cont = continuation
    }

    func tryResume(_ status: StatusProbe.Status) {
        lock.lock()
        defer { lock.unlock() }
        guard let c = cont else { return }
        cont = nil
        c.resume(returning: status)
    }
}
