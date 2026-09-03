import Foundation

/// qtunnel 加密方法 — 决策 1/2
enum CryptoMethod: String, Codable, CaseIterable, Sendable {
    case rc4
    case aes256cfb

    /// qtunnel-server `-crypto` 参数
    var cliValue: String {
        switch self {
        case .rc4: return "rc4"
        case .aes256cfb: return "aes256cfb"
        }
    }

    /// 加密 key 字节长度
    var keySize: Int {
        switch self {
        case .rc4: return 16
        case .aes256cfb: return 32
        }
    }
}
