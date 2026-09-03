import Foundation

/// RC4 流密码 — iOS CommonCrypto 无 RC4，自带实现
/// 移植自 Go `crypto/rc4`
final class RC4Cipher: Cipher, @unchecked Sendable {

    private var s: [UInt8]
    private var i: UInt8 = 0
    private var j: UInt8 = 0

    init(key: [UInt8]) {
        precondition(key.count >= 1 && key.count <= 256, "RC4 key must be 1-256 bytes")
        // KSA
        s = [UInt8](0...255)
        var j: UInt8 = 0
        for i in 0..<256 {
            j &+= s[i] &+ key[i % key.count]
            s.swapAt(i, Int(j))
        }
    }

    func encrypt(_ data: inout [UInt8]) {
        // RC4 encrypt == decrypt
        crypt(&data)
    }

    func decrypt(_ data: inout [UInt8]) {
        crypt(&data)
    }

    private func crypt(_ data: inout [UInt8]) {
        for k in 0..<data.count {
            i &+= 1
            j &+= s[Int(i)]
            s.swapAt(Int(i), Int(j))
            let t = s[Int(i) &+ Int(j) & 0xFF]
            data[k] ^= t
        }
    }
}
