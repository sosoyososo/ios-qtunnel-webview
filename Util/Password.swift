import Foundation
import Security

/// 密码生成 — 决策 8：32 chars [a-z0-9]
enum Password {

    /// 生成 32 字符 [a-z0-9] 密码
    /// 使用 SecRandomCopyBytes 保证密码学安全
    static func generate(length: Int = 32) -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var bytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(result == errSecSuccess, "SecRandomCopyBytes failed")
        // 通过 modulo 选字符；模偏置可忽略（密码生成不需要严格 unbiased）
        let chars: [Character] = bytes.map { charset[Int($0) % charset.count] }
        return String(chars)
    }
}
