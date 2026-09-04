import XCTest
@testable import Qtunnel
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// End-to-end tunnel test — runs against a live qtunnel-server + mock backend
/// Setup (manual):
///   1. mock backend:  python3 /tmp/mock_backend.py 28080
///   2. qtunnel-server:  /tmp/qtunnel-server -listen=:29001 -backend=127.0.0.1:28080 -crypto=rc4 -secret=testsecret
/// Tests skip if those aren't running.
final class EndToEndTunnelTests: XCTestCase {

    private let host = "127.0.0.1"
    private let port = 29001
    private let secret = "testsecret"

    func test_httpsRequestThroughTunnel() async throws {
        let available = await isLiveTunnelAvailable()
        if !available {
            throw XCTSkip("qtunnel-server + mock backend not running on 127.0.0.1:\(port)")
        }

        let plainRequest = Data("GET / HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n".utf8)
        let response = try await sendAndReceive(plain: plainRequest, timeoutMs: 5000)

        let responseStr = String(decoding: response, as: UTF8.self)
        // Backend serves /Users/karsa/proj/qtunnel (via fileServer tool).
        // Asserting generic HTTP 200 + presence of qtunnel directory entry.
        XCTAssertTrue(responseStr.contains("200 OK"),
                      "Response should be HTTP 200, got first 200 chars: \(responseStr.prefix(200))")
        XCTAssertTrue(responseStr.contains("qtunnel-ios-web") || responseStr.contains("qtunnel-server"),
                      "Response should list qtunnel directory contents")
    }

    // MARK: - Live check

    private func isLiveTunnelAvailable() async -> Bool {
        let status = await StatusProbe.probeOnce(host: host, port: port, timeout: .seconds(2))
        return status == .up
    }

    // MARK: - POSIX socket send/recv (avoids NWConnection timing)

    private func sendAndReceive(plain: Data, timeoutMs: Int32) async throws -> Data {
        let cipher = CipherFactory.make(method: .rc4, secret: secret)
        let encrypted = cipher.encrypt(plain)
        let (sockAddr, _) = try makeAddr()

        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else {
            throw NSError(domain: "E2E", code: 1, userInfo: [NSLocalizedDescriptionKey: "socket() failed"])
        }
        defer { close(fd) }

        // non-blocking
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var sockAddrVar = sockAddr
        let rc = withUnsafePointer(to: &sockAddrVar) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                connect(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if rc != 0 && errno != EINPROGRESS {
            throw NSError(domain: "E2E", code: 2, userInfo: [NSLocalizedDescriptionKey: "connect() failed: \(String(cString: strerror(errno)))"])
        }
        if rc != 0 {
            // wait for connect-ready
            var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let pr = poll(&pfd, 1, timeoutMs)
            if pr <= 0 {
                throw NSError(domain: "E2E", code: 3, userInfo: [NSLocalizedDescriptionKey: "connect timeout"])
            }
            var soErr: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            if getsockopt(fd, SOL_SOCKET, SO_ERROR, &soErr, &len) != 0 || soErr != 0 {
                throw NSError(domain: "E2E", code: 4, userInfo: [NSLocalizedDescriptionKey: "so_error: \(soErr)"])
            }
        }

        // send encrypted request (loop until all bytes sent)
        var totalSent = 0
        var sendOffset = 0
        let sendDeadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while sendOffset < encrypted.count {
            let remaining = encrypted.count - sendOffset
            let n = encrypted.withUnsafeBytes { ptr -> Int in
                Darwin.send(fd, ptr.baseAddress!.advanced(by: sendOffset), remaining, 0)
            }
            if n > 0 {
                sendOffset += n
                totalSent += n
                continue
            }
            if n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) {
                var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
                let pr = poll(&pfd, 1, 200)
                if pr <= 0 { break }
                continue
            }
            break
        }
        XCTAssertEqual(totalSent, encrypted.count, "should send full encrypted payload, sent=\(totalSent)")

        // 等待数据（server 加密 backend 响应）
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let ready = poll(&pfd, 1, timeoutMs)
        if ready <= 0 {
            throw NSError(domain: "E2E", code: 7, userInfo: [NSLocalizedDescriptionKey: "no response within timeout, ready=\(ready)"])
        }

        // read response with timeout
        var collected = [UInt8]()
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            var buf = [UInt8](repeating: 0, count: 4096)
            let n = buf.withUnsafeMutableBufferPointer { ptr -> Int in
                recv(fd, ptr.baseAddress, ptr.count, 0)
            }
            if n > 0 {
                buf.removeSubrange(n..<buf.count)
                let plain = cipher.decrypt(Data(buf))
                collected.append(contentsOf: plain)
                // 检查是否完整（HTTP 响应 + Connection: close 后 FIN）
                if let lastFew = String(bytes: collected.suffix(50), encoding: .utf8),
                   lastFew.contains("hello from backend") {
                    return Data(collected)
                }
            } else if n == 0 {
                // EOF
                break
            } else {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    // 等数据
                    var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
    _ = poll(&pfd, 1, 200)
                    continue
                }
                break
            }
        }

        return Data(collected)
    }

    private func makeAddr() throws -> (sockaddr_in, Int) {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        let err = getaddrinfo(host, String(port), &hints, &result)
        guard err == 0, let p = result?.pointee else {
            throw NSError(domain: "E2E", code: 6, userInfo: [NSLocalizedDescriptionKey: "getaddrinfo failed: \(err)"])
        }
        defer { freeaddrinfo(result) }
        let addr = p.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        return (addr, 1)
    }
}
