// Minimal test harness — uses existing shared code (Cipher, TunnelConnection, etc.)
// NOT a copy — this file is compiled together with the real source files.

import Foundation

@main
struct TestMain {
    static func main() {
        let host = "127.0.0.1"
        let port = 29001
        let secret = "testsecret"

        print("=== tunnel E2E test ===")
        print("Cipher: RC4, Secret: \(secret)")
        print("Target: \(host):\(port)")

        // Create cipher using shared CipherFactory
        let cipher = CipherFactory.make(method: .rc4, secret: secret)
        print("Cipher created OK")

        // Create tunnel connection using shared TunnelConnection
        let tunnel = TunnelConnection(host: host, port: port, cipher: cipher)

        // HTTP request
        let httpRequest = "GET / HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n"
        print("Request: \(httpRequest.trimmingCharacters(in: .whitespacesAndNewlines))")

        // Collect response
        let responseReady = DispatchSemaphore(value: 0)
        var responseData = Data()

        tunnel.onReceive = { data in
            responseData.append(data)
            if let str = String(data: responseData, encoding: .utf8),
               str.contains("\r\n\r\n") {
                responseReady.signal()
            }
        }

        tunnel.onState = { state in
            switch state {
            case .ready:
                print("Tunnel connected!")
                tunnel.send(Data(httpRequest.utf8))
                print("Request sent (\(httpRequest.count) bytes)")
            case .failed(let err):
                print("Tunnel FAILED: \(err)")
                responseReady.signal()
            case .closed:
                print("Tunnel closed")
                responseReady.signal()
            default:
                break
            }
        }

        print("Connecting...")
        tunnel.connect()

        let timeout = responseReady.wait(timeout: .now() + 5.0)
        tunnel.disconnect()

        if timeout == .timedOut {
            print("TIMEOUT: No response within 5 seconds")
            exit(1)
        }

        if responseData.isEmpty {
            print("ERROR: Empty response")
            exit(1)
        }

        let responseStr = String(data: responseData, encoding: .utf8) ?? "(binary)"
        print("\n=== Response (\(responseData.count) bytes) ===")
        print(responseStr)
        print("=== End ===")

        if responseStr.contains("200 OK") {
            print("\nSUCCESS: HTTP 200 through tunnel tunnel!")
        } else if responseStr.contains("404") {
            print("\nPARTIAL: Connected through tunnel, got 404 (backend running but path not found)")
        } else {
            print("\nUNEXPECTED: \(responseStr.prefix(200))")
        }
    }
}
