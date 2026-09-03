import Foundation
import CommonCrypto

/// AES-256-CFB 流密码 — CommonCrypto 包装
/// 关键：IV = key[:16]（与 qtunnel-server 一致）
/// encrypt / decrypt 各自独立 cryptor（与 Go 一致）
final class AES256CFBCipher: Cipher, @unchecked Sendable {

    private let key: [UInt8]
    private let iv: [UInt8]
    private let lock = NSLock()
    private var encCryptor: CCCryptorRef?
    private var decCryptor: CCCryptorRef?

    init(key: [UInt8]) {
        precondition(key.count == 32, "AES-256 key must be 32 bytes")
        self.key = key
        self.iv = Array(key.prefix(16))
        self.encCryptor = makeCryptor(op: CCOperation(kCCEncrypt))
        self.decCryptor = makeCryptor(op: CCOperation(kCCDecrypt))
    }

    deinit {
        if let c = encCryptor { CCCryptorRelease(c) }
        if let c = decCryptor { CCCryptorRelease(c) }
    }

    func encrypt(_ data: inout [UInt8]) {
        process(&data, cryptor: encCryptor)
    }

    func decrypt(_ data: inout [UInt8]) {
        process(&data, cryptor: decCryptor)
    }

    // MARK: - Private

    private func makeCryptor(op: CCOperation) -> CCCryptorRef? {
        var cryptor: CCCryptorRef?
        let status = key.withUnsafeBufferPointer { keyPtr in
            iv.withUnsafeBufferPointer { ivPtr in
                guard let keyBase = keyPtr.baseAddress, let ivBase = ivPtr.baseAddress else {
                    return Int32(kCCAlignmentError)
                }
                return CCCryptorCreateWithMode(
                    op,
                    CCMode(kCCModeCFB),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCPadding(ccNoPadding),
                    ivBase,
                    keyBase, key.count,
                    nil, 0, 0,
                    CCModeOptions(kCCModeOptionCTR_BE),
                    &cryptor
                )
            }
        }
        if status != kCCSuccess {
            Log.error("Cipher", "CCCryptorCreateWithMode(\(op)) failed: \(status)")
            return nil
        }
        return cryptor
    }

    private func process(_ data: inout [UInt8], cryptor: CCCryptorRef?) {
        guard let cryptor else { return }
        lock.lock()
        defer { lock.unlock() }

        let input = data  // 拷贝避免 inout 重叠
        let bufSize = CCCryptorGetOutputLength(cryptor, input.count, true)
        var out = [UInt8](repeating: 0, count: bufSize)
        var bytesOut = 0

        let updateStatus = input.withUnsafeBufferPointer { dataPtr in
            out.withUnsafeMutableBufferPointer { outPtr in
                guard let outBase = outPtr.baseAddress else { return Int32(kCCAlignmentError) }
                return CCCryptorUpdate(
                    cryptor,
                    dataPtr.baseAddress, dataPtr.count,
                    outBase, bufSize,
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
            guard let outBase = outPtr.baseAddress else { return Int32(kCCAlignmentError) }
            return CCCryptorFinal(
                cryptor,
                outBase.advanced(by: bytesOut),
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
