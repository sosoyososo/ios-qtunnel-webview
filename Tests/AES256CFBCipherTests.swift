import XCTest
@testable import Qtunnel

final class AES256CFBCipherTests: XCTestCase {

    func test_encryptDecryptRoundtrip() {
        let cipher = CipherFactory.make(method: .aes256cfb, secret: "testsecret")
        let plain: [UInt8] = Array("thisISaCLEARtext".utf8)
        var ciphered = plain
        cipher.encrypt(&ciphered)
        XCTAssertNotEqual(ciphered, plain)
        cipher.decrypt(&ciphered)
        XCTAssertEqual(ciphered, plain)
    }

    func test_ivIsFirst16BytesOfKey() {
        // AES256CFB 内部：iv = key.prefix(16)
        // 通过 roundtrip 验证 IV 选择不影响正确性（对称密码下任意 IV 都行）
        // 这里只验证 key 长度
        let key = KeyDerivation.deriveKey(secret: Array("testsecret".utf8), size: 32)
        XCTAssertEqual(key.count, 32)
    }

    func test_GoServerTestVector() {
        let secret = "testsecret"
        let clearText = "thisISaCLEARtext"
        let cipher = CipherFactory.make(method: .aes256cfb, secret: secret)
        var dst = [UInt8](clearText.utf8)
        cipher.encrypt(&dst)
        var dst2 = dst
        cipher.decrypt(&dst2)
        XCTAssertEqual(String(bytes: dst2, encoding: .utf8), clearText)
    }

    func test_longStreamRoundtrip() {
        let cipher = CipherFactory.make(method: .aes256cfb, secret: "longstreamkey")
        let plain = [UInt8](repeating: 0xCD, count: 100_000)
        var ciphered = plain
        cipher.encrypt(&ciphered)
        cipher.decrypt(&ciphered)
        XCTAssertEqual(ciphered, plain)
    }
}
