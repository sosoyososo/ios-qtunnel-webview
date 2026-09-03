import Foundation

/// WebView 状态 — UI 持久化用
/// title 格式：{client_name}[{indexInConfig or nothing}]
struct WebViewState: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var clientInstanceId: UUID
    /// 同 instance 内的 webview 序号（1-based；用于 title 展示）
    var indexInConfig: Int
    /// iPad 上的浮动位置；iPhone 忽略
    var position: Position?
    /// 是否处于聚焦态
    var isFocused: Bool

    struct Position: Codable, Hashable, Sendable {
        var x: Double
        var y: Double
    }

    init(
        id: UUID = UUID(),
        clientInstanceId: UUID,
        indexInConfig: Int,
        position: Position? = nil,
        isFocused: Bool = false
    ) {
        self.id = id
        self.clientInstanceId = clientInstanceId
        self.indexInConfig = indexInConfig
        self.position = position
        self.isFocused = isFocused
    }
}
