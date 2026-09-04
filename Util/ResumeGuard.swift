import Foundation

/// 防止 CheckedContinuation 多次 resume 的包装
final class ResumeGuard<T>: @unchecked Sendable {
    private var cont: CheckedContinuation<T, Never>?
    private let lock = NSLock()

    func setContinuation(_ continuation: CheckedContinuation<T, Never>) {
        lock.lock()
        defer { lock.unlock() }
        self.cont = continuation
    }

    /// 返回 true 表示成功 resume
    @discardableResult
    func resume(returning value: T) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let c = cont else { return false }
        cont = nil
        c.resume(returning: value)
        return true
    }
}