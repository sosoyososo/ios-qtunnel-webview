import XCTest
@testable import Qtunnel

/// Key 派生测试 — 复现 Go 服务端 cipher.go
/// ⚠️ 末字节 0x00（off-by-one）是协议契约，不能修复
/// 详见 qtunnel-server/doc/PROTOCOL.md
final class KeyDerivationTests: XCTestCase {

    func test_RC4_keyMatchesGoServer() {
        // 实测：secret="testsecret" → 16 字节 RC4 key，末字节为 0x00
        let key = KeyDerivation.deriveKey(secret: Array("testsecret".utf8), size: 16)
        let hex = key.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "217df19d942a4a990ebeed63a9832900")
        XCTAssertEqual(key.last, 0x00, "末字节必须是 0x00（off-by-one 协议契约）")
    }

    func test_AES_keyMatchesGoServer() {
        // 实测：secret="testsecret" → 32 字节 AES key
        let key = KeyDerivation.deriveKey(secret: Array("testsecret".utf8), size: 32)
        let hex = key.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "217df19d942a4a990ebeed63a983290090f479b95beada82d9c387d3a9989d00")
        XCTAssertEqual(key[15], 0x00, "第 16 字节必须是 0x00")
        XCTAssertEqual(key[31], 0x00, "第 32 字节必须是 0x00")
    }

    func test_differentSecretsProduceDifferentKeys() {
        let a = KeyDerivation.deriveKey(secret: Array("a".utf8), size: 16)
        let b = KeyDerivation.deriveKey(secret: Array("b".utf8), size: 16)
        XCTAssertNotEqual(a, b)
    }

    func test_emptySecretProducesStableKey() {
        let key = KeyDerivation.deriveKey(secret: [], size: 16)
        XCTAssertEqual(key.count, 16)
        // 每次调用结果一致
        let key2 = KeyDerivation.deriveKey(secret: [], size: 16)
        XCTAssertEqual(key, key2)
    }
}
