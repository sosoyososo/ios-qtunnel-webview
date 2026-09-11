import Foundation

/// UserDefaults key 常量 — spec 01 §6
enum Keys {
    /// 整个 StoredData 单 key
    static let store = "tunnel.store.v1"
    /// onboarding 是否已展示过 — 与 store JSON 独立，避免数据迁移
    static let hasSeenOnboarding = "tunnel.onboarding.v1"
}
