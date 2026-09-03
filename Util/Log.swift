import Foundation
import os

/// 极简 logger，统一接口、tag 前缀、自动 level
enum Log {
    private static let subsystem = "com.karsa.qtunnel.app"

    static func debug(_ tag: String, _ msg: String) {
        os_log(.debug, "%{public}@", "\(tag) \(msg)")
    }
    static func info(_ tag: String, _ msg: String) {
        os_log(.info, "%{public}@", "\(tag) \(msg)")
    }
    static func error(_ tag: String, _ msg: String) {
        os_log(.error, "%{public}@", "\(tag) \(msg)")
    }
}
