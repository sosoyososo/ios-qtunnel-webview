import Foundation

/// 流加密协议 — spec 01 §4.1
/// encrypt/decrypt 都是 in-place XOR，匹配 qtunnel-server `Cipher.encrypt/decrypt`
protocol Cipher: Sendable {
    func encrypt(_ data: inout [UInt8])
    func decrypt(_ data: inout [UInt8])
}

extension Cipher {
    /// 便利方法：Data → Data
    func encrypt(_ data: Data) -> Data {
        var bytes = [UInt8](data)
        encrypt(&bytes)
        return Data(bytes)
    }

    func decrypt(_ data: Data) -> Data {
        var bytes = [UInt8](data)
        decrypt(&bytes)
        return Data(bytes)
    }
}

/// Cipher 工厂
enum CipherFactory {

    /// 从 secret 创建 cipher
    /// - Parameters:
    ///   - method: 加密方法
    ///   - secret: 明文密码
    static func make(method: CryptoMethod, secret: String) -> Cipher {
        let secretBytes = [UInt8](secret.utf8)
        let key = KeyDerivation.deriveKey(secret: secretBytes, size: method.keySize)
        switch method {
        case .rc4:
            return RC4Cipher(key: key)
        case .aes256cfb:
            return AES256CFBCipher(key: key)
        }
    }
}
