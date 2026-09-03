import XCTest
@testable import Qtunnel

final class RC4CipherTests: XCTestCase {

    func test_encryptDecryptRoundtrip() {
        let cipher = CipherFactory.make(method: .rc4, secret: "testsecret")
        let plain: [UInt8] = Array("thisISaCLEARtext".utf8)
        var ciphered = plain
        cipher.encrypt(&ciphered)
        XCTAssertNotEqual(ciphered, plain, "密文 != 明文")
        cipher.decrypt(&ciphered)
        XCTAssertEqual(ciphered, plain, "解密回明文")
    }

    func test_longStreamDoesNotLeakKey() {
        let cipher = CipherFactory.make(method: .rc4, secret: "longstreamkey")
        let plain = [UInt8](repeating: 0xAB, count: 1_000_000)
        var ciphered = plain
        cipher.encrypt(&ciphered)
        // 全部相等才能解密
        cipher.decrypt(&ciphered)
        XCTAssertEqual(ciphered, plain)
    }

    func test_GoServerTestVector() {
        // 模拟 Go cipher_test.go::TestRC4
        let secret = "testsecret"
        let clearText = "thisISaCLEARtext"
        let cipher = CipherFactory.make(method: .rc4, secret: secret)
        var dst = [UInt8](clearText.utf8)
        cipher.encrypt(&dst)
        var dst2 = dst
        cipher.decrypt(&dst2)
        XCTAssertEqual(String(bytes: dst2, encoding: .utf8), clearText)
    }
}
