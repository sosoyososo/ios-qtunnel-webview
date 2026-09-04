import Foundation

/// NavigationStack 的 destination 包装类型
/// 避免多个 `navigationDestination(for: UUID.self)` 之间的歧义
enum NavTarget: Hashable {
    case server(UUID)
    case config(UUID)
    case instance(UUID)
}