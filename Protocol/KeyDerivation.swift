import Foundation
import CryptoKit

// 桥接 CommonCrypto 的 MD5（Swift CryptoKit 没有 MD5）
import CommonCrypto

/// Key 派生 — 复现 qtunnel-server `cipher.go::secretToKey`
/// ⚠️ 含 off-by-one（末字节 0x00），详见 qtunnel-server/doc/PROTOCOL.md
/// 这是协议契约的一部分，**不能修复**
enum KeyDerivation {

    /// secret → key（size 必须为 16 的倍数）
    static func deriveKey(secret: [UInt8], size: Int) -> [UInt8] {
        precondition(size % 16 == 0, "size must be multiple of md5.Size (16)")
        var buf = [UInt8](repeating: 0, count: size)
        let count = size / 16

        var md5 = MD5()
        for i in 0..<count {
            md5.update(secret)
            let sum = md5.finalize()
            // off-by-one: copy 到 [16*i : 16*(i+1)-1] = 15 bytes
            for j in 0..<15 {
                buf[16 * i + j] = sum[j]
            }
            // buf[16*(i+1)-1] 保留为 0
            // ⚠️ 不重置 md5，模拟 Go `h.Write` 累积（i=0 时 sum=MD5(secret), i=1 时 sum=MD5(secret||secret)）
        }
        return buf
    }

    // MARK: - MD5 helper

    private struct MD5 {
        var context = CC_MD5_CTX()

        init() {
            CC_MD5_Init(&context)
        }

        mutating func update(_ bytes: [UInt8]) {
            bytes.withUnsafeBufferPointer { ptr in
                _ = CC_MD5_Update(&context, ptr.baseAddress, CC_LONG(ptr.count))
            }
        }

        func finalize() -> [UInt8] {
            var digest = [UInt8](repeating: 0, count: 16)
            var ctx = context  // copy
            digest.withUnsafeMutableBufferPointer { ptr in
                _ = CC_MD5_Final(ptr.baseAddress, &ctx)
            }
            return digest
        }
    }
}
