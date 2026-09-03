import Foundation
import CommonCrypto

/// AES-256-CFB 流密码 — CommonCrypto 包装
/// 关键：IV = key[:16]（与 qtunnel-server 一致）
final class AES256CFBCipher: Cipher, @unchecked Sendable {

    private let key: [UInt8]
    private let iv: [UInt8]
    private let lock = NSLock()

    init(key: [UInt8]) {
        precondition(key.count == 32, "AES-256 key must be 32 bytes")
        self.key = key
        self.iv = Array(key.prefix(16))
    }

    func encrypt(_ data: inout [UInt8]) {
        process(&data, op: kCCEncrypt)
    }

    func decrypt(_ data: inout [UInt8]) {
        process(&data, op: kCCDecrypt)
    }

    private func process(_ data: inout [UInt8], op: CCOperation) {
        lock.lock()
        defer { lock.unlock() }

        var cryptor: CCCryptorRef?
        let status = key.withUnsafeBufferPointer { keyPtr in
            iv.withUnsafeBufferPointer { ivPtr in
                CCCryptorCreateWithMode(
                    op,
                    kCCModeCFB,
                    kCCAlgorithmAES,
                    ccNoPadding,
                    ivPtr.baseAddress,
                    keyPtr.baseAddress, key.count,
                    nil, 0, 0,
                    CCModeOptions(kCCModeOptionCTR_BE),
                    &cryptor
                )
            }
        }
        guard status == kCCSuccess, let cryptor else {
            Log.error("Cipher", "CCCryptorCreateWithMode failed: \(status)")
            return
        }
        defer { CCCryptorRelease(cryptor) }

        let bufSize = CCCryptorGetOutputLength(cryptor, data.count, true)
        var out = [UInt8](repeating: 0, count: bufSize)
        var bytesOut = 0

        let updateStatus = data.withUnsafeMutableBufferPointer { dataPtr in
            out.withUnsafeMutableBufferPointer { outPtr in
                CCCryptorUpdate(
                    cryptor,
                    dataPtr.baseAddress, data.count,
                    outPtr.baseAddress, bufSize,
                    &bytesOut
                )
            }
        }
        guard updateStatus == kCCSuccess else {
            Log.error("Cipher", "CCCryptorUpdate failed: \(updateStatus)")
            return
        }

        var finalOut = 0
        let finalStatus = out.withUnsafeMutableBufferPointer { outPtr in
            CCCryptorFinal(
                cryptor,
                outPtr.baseAddress.advanced(by: bytesOut),
                bufSize - bytesOut,
                &finalOut
            )
        }
        guard finalStatus == kCCSuccess else {
            Log.error("Cipher", "CCCryptorFinal failed: \(finalStatus)")
            return
        }

        let total = bytesOut + finalOut
        data = Array(out.prefix(total))
    }
}
