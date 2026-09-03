import Foundation

/// 拼接 qtunnel-server 启动命令
/// 决策：跨平台可粘贴运行（POSIX 风格 backslash 续行）
enum ServerCmd {

    /// 生成命令字符串
    /// - Parameters:
    ///   - listenPort: server 监听端口
    ///   - backendHost: 后端 host（通常是 127.0.0.1）
    ///   - backendPort: 后端 port
    ///   - crypto: 加密方法
    ///   - secret: 32-char 密码
    ///   - executable: 可执行文件路径，默认 `qtunnel`
    static func build(
        listenPort: Int,
        backendHost: String,
        backendPort: Int,
        crypto: String,
        secret: String,
        executable: String = "qtunnel"
    ) -> String {
        """
        \(executable) -listen=:\(listenPort) \\
          -backend=\(backendHost):\(backendPort) \\
          -crypto=\(crypto) \\
          -secret=\(secret)
        """
    }
}
