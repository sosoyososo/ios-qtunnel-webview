import Foundation

/// RC4 流密码 — iOS CommonCrypto 无 RC4，自带实现
/// 移植自 Go `crypto/rc4`
/// 注意：encrypt 和 decrypt 各自维护独立 RC4 状态（与 Go 一致）
final class RC4Cipher: Cipher, @unchecked Sendable {

    private let encState: RC4State
    private let decState: RC4State

    init(key: [UInt8]) {
        precondition(key.count >= 1 && key.count <= 256, "RC4 key must be 1-256 bytes")
        self.encState = RC4State(key: key)
        self.decState = RC4State(key: key)
    }

    func encrypt(_ data: inout [UInt8]) {
        encState.crypt(&data)
    }

    func decrypt(_ data: inout [UInt8]) {
        decState.crypt(&data)
    }
}

/// RC4 状态机（独立可复制）
private final class RC4State {
    var s: [UInt8]
    var i: Int = 0
    var j: Int = 0

    init(key: [UInt8]) {
        var s = [UInt8](0...255)
        var j: Int = 0
        for i in 0..<256 {
            j = (j + Int(s[i]) + Int(key[i % key.count])) & 0xFF
            s.swapAt(i, j)
        }
        self.s = s
    }

    func crypt(_ data: inout [UInt8]) {
        for k in 0..<data.count {
            i = (i + 1) & 0xFF
            j = (j + Int(s[i])) & 0xFF
            // ⚠️ 关键：用 s[i] 和 s[j] 的**值**（不是位置 i/j）算 keystream 索引
            let si = Int(s[i])
            let sj = Int(s[j])
            s.swapAt(i, j)
            let t = s[(si + sj) & 0xFF]
            data[k] ^= t
        }
    }
}
