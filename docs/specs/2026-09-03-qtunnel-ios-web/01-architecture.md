# 01 — Architecture

## 1. 目标 & 非目标

**目标**：iOS app 让用户配置 qtunnel 客户端、生成 server 启动命令、维护多个长连接、显示多个 WebView。

**非目标**：见 `00-overview.md` §范围。

## 2. 模块结构

```
qtunnel-ios-web/
├── App/                        # App entry
│   └── QtunnelApp.swift
├── DesignSystem/               # 设计 token + 基础组件
│   ├── DS.swift                # Color/Spacing/Radius/Font
│   └── Components/             # DSButton, DSCard, DSListRow
├── Models/                     # 纯数据模型
│   ├── Server.swift
│   ├── ClientConfig.swift
│   ├── ClientInstance.swift
│   ├── WebViewState.swift
│   └── CryptoMethod.swift
├── Storage/                    # 持久化
│   ├── Store.swift             # @ObservableObject，统一读写 UserDefaults
│   └── Keys.swift              # UserDefaults key 常量
├── Protocol/                   # qtunnel 协议层（iOS 实现）
│   ├── Cipher.swift            # 协议接口
│   ├── RC4Cipher.swift         # 自带 RC4（iOS CommonCrypto 无 RC4）
│   ├── AES256CFBCipher.swift   # CCCryptor
│   ├── KeyDerivation.swift     # MD5 派生（复现 server off-by-one）
│   ├── TunnelConnection.swift  # 单条 clientInstance 的 TCP
│   └── Heartbeat.swift         # 5min 心跳
├── Networking/
│   ├── StatusProbe.swift       # TCP connect probe
│   ├── LocalListener.swift     # 每个 instance 监听 127.0.0.1:random
│   └── TCPForwarder.swift      # LocalListener <-> TunnelConnection 桥
├── StateMachine/               # 每个实体的状态机
│   ├── ServerState.swift
│   ├── ClientInstanceState.swift
│   └── WebViewState.swift
├── UI/                         # SwiftUI 视图
│   ├── ServerList/
│   ├── ServerEdit/
│   ├── ClientConfigList/
│   ├── ClientConfigEdit/
│   ├── ClientInstanceList/
│   ├── WebViewCanvas/
│   └── Components/             # 视图级组件
└── Util/
    ├── Password.swift          # 生成 32-char 密码
    ├── ServerCmd.swift         # 拼接启动命令
    └── Log.swift
```

每个模块的接口见 §3 状态机。

## 3. 状态机

### 3.1 Server

```
Unknown ──probe()──► Up
   │                 │
   │                 └──probe()──► Down
   └──probe()──► Down
```

- 初始：Unknown（未探）
- 触发：10s 定时器 / 用户手动刷新 / 进入编辑页
- 状态：`unknown` / `up` / `down`
- 实现：`StatusProbe` actor，**DNS 解析 + NWPath**（Server 不带端口，无法 TCP probe）

### 3.2 ClientConfig

```
Draft ──save()──► Saved
                    │
                    ├──createInstance()──► hasInstance
                    ├──delete()──► (removed)
                    └──regeneratePassword()──► Saved (密码字段变)
```

- 字段：id、name、serverId、**qtunnelPort**（qtunnel-server 监听端口）、cryptoMethod、secret、backendHost（默认 127.0.0.1）、backendPort
- 状态：`draft` / `saved`
- 行为：
  - 保存 → 创建 1 个 ClientInstance（默认行为，见 §3.3）
  - 重置密码 → secret 变化 → 通知所属 ClientInstance 重启

### 3.3 ClientInstance

```
Idle ──start(short=false)──► Handshaking ──ok──► Running
   │                          │                   │
   │                          └──fail──► Failed   │
   │                                              │
   │                          ┌───────────────────┘
   │                          │ heartbeat fail / TCP close
   │                          ▼
   └─start(short=true)──► Handshaking ──ok──► Idle (test 完成后关闭)
                          │
                          └──fail──► Idle (test 失败，关闭)
```

- 字段：id、clientConfigId、localPort（随机）
- 状态：`idle` / `handshaking` / `running` / `failed` / `stopped`
- 行为：
  - `start(short=false)` → 监听 127.0.0.1:localPort → 发起 TCP 到 `Server.host:ClientConfig.qtunnelPort` → Handshaking
  - TCP 握手 ok → Running，启 Heartbeat Task
  - Heartbeat fail / TCP close → Stopped
  - `start(short=true)` → 同上但 timeout=5s，**成功/失败后都关闭连接**，回到 `idle`。仅用于 Test Client（决策 2）
  - 重启策略：手动 start()（不自动重连）

### 3.4 WebView

```
Pending ──create──► Loading ──didFinish──► Loaded
                                              │
                                              ├──hide()──► Hidden
                                              ├──focus()──► Focused
                                              └──close()──► (removed)
```

- 字段：id、clientInstanceId、indexInConfig、homeURL（自动 = `http://127.0.0.1:{localPort}/`）、position（iPad）
- 状态：`pending` / `loading` / `loaded` / `hidden` / `focused`
- 行为：
  - create → Pending → 创建 WKWebView → Loading
  - didFinish → Loaded
  - 用户 tap → Focused；其他 webview → Hidden
  - iPhone 上 Focused = 全屏；iPad 上 Focused = z-top
  - chrome 顶栏：title + ←🏠→✕（back / home / forward / close）；back/forward 通过 WKWebView.canGoBack / canGoForward 联动，home 加载 homeURL

### 3.5 状态机组合

整个 app 的"系统状态"由四个独立状态机组合而成，UI 渲染由各状态机独立订阅。

## 4. 协议层

### 4.1 qtunnel cipher

iOS 实现与 Go 端 1:1 对齐，**保留 off-by-one**（见 `qtunnel-server/doc/PROTOCOL.md` §Key Derivation）。

| 算法 | iOS API | 备注 |
|---|---|---|
| RC4 | 自带实现（无 CommonCrypto API） | 移植自 Go `crypto/rc4`；**PRGA 索引用 s[i]+s[j]（值），非 i+j（位置）**（决策 18） |
| AES256-CFB | `CCCryptorCreate(kCCAlgorithmAES128, kCCModeCFB, kCCOptionECB_None, key, 32, iv)` | IV = key[:16] |
| MD5 | `CC_MD5` | 标准 |

**关键**：
- KeyDerivation 必须逐字节复现 Go 的 `secretToKey`（含 `-1` off-by-one）。详见 `qtunnel-server/src/tunnel/cipher.go:23-34`
- RC4 PRGA 标准算法为 `K = S[(S[i] + S[j]) mod 256]`，**不是** `S[(i+j) mod 256]`（常见错误）。详见 `Protocol/RC4Cipher.swift:RC4State.crypt`。

### 4.2 TunnelConnection

单条长连接：

```
LocalListener (127.0.0.1:R)
  ↕ plain bytes
TCPForwarder
  ↕ encrypt/decrypt on each byte stream
TunnelConnection
  ↕ encrypted bytes over Internet TCP
qtunnel-server
```

- TCP 读循环：`recv → decrypt → forward to local`
- TCP 写循环：`local → encrypt → send`
- 心跳：每 5 min 发 1 byte `0x00`（加密后）

### 4.3 Heartbeat

- 间隔：5 min
- payload：1 byte `0x00`（明文 → 加密后 17 bytes for RC4、17 for AES-CFB）
- 触发：iOS 端单方面发送；server 不要求 ack（30min idle timeout 自动重置）
- 检测：连续 2 次未发送成功 → 标记 ClientInstance 为 `stopped`

### 4.4 StatusProbe

- Server 不携带端口（决策 5 修订），改用 **DNS resolve + NWPath**
  - DNS：getaddrinfo(host) 成功解析 → host 存在
  - NWPath：status == .satisfied → 网络可达
  - 两者皆为 true → `up`，否则 → `down`
- 间隔：10s（Server 仅作可达性指示，无需高频）
- NWPathMonitor 长期持有，路径变化即触发回调（不需等下一周期）
- 配置端口的可达性（如需探测 qtunnel-server 是否真在监听 `Config.qtunnelPort`）留待 Config 级别扩展（未实现）

## 5. 数据流

### 5.1 启动 server start cmd 流程

```
User (ServerEdit screen)
  → 输入 server host（实时 DNS 探活）
  → Store.save(server)
  → User 进入 ClientConfigEdit
  → 输入 qtunnelPort（server 监听端口）+ backendPort
  → 选择 crypto method
  → Password.generate() → 32-char string
  → Store.save(clientConfig) [含 secret + qtunnelPort]
  → User 点击 "Generate Server Cmd"
  → ServerCmd.build(listenPort=cfg.qtunnelPort, backendPort=cfg.backendPort, ...) → 字符串
  → Show in modal with copy button
  → User SSH 到 VPS，粘贴运行
```

### 5.2 Run Client 流程

```
User (ClientInstance row)
  → 点击 "Run"
  → ClientInstance.start()
  → LocalListener.bind(127.0.0.1:0) → localPort
  → TunnelConnection.connect(server.host, clientConfig.qtunnelPort)
  → TCPForwarder.start(localListener, tunnelConnection)
  → Heartbeat.start()
  → State: idle → handshaking → running
```

### 5.3 Open WebView 流程

```
User (ClientInstance row)
  → 点击 "Open WebView"
  → WebViewState.create(clientInstanceId)
  → homeURL = "http://127.0.0.1:{localPort}/"
  → WKWebView.load(homeURL)
  → State: pending → loading → loaded → focused
  → UI: 加入 tab strip / 浮动到 z-top
```

## 6. 持久化

UserDefaults 单例（`Store`），schema：

```swift
struct StoredData: Codable {
    servers: [Server]
    clientConfigs: [ClientConfig]
    clientInstances: [ClientInstance]   // 含 localPort、状态
    webViews: [WebViewState]            // 含 indexInConfig、position
}

enum Keys {
    static let store = "qtunnel.store.v1"
}
```

约束：
- 整个 `StoredData` 一个 key，单 JSON 序列化（含 secret 字段）
- 写：每次 mutation 整体重写（数据量小，可接受）
- 读：app 启动一次
- 失败：JSON parse error → 降级到空 + Log.error（不丢旧数据，保留旧 key 供用户恢复）

**secret 字段**作为 ClientConfig 的一部分存入 StoredData（即决策 7：明文，不另立文件，不进 Keychain）。

## 7. 并发

- Swift `actor` for：StatusProbe、TunnelConnection、LocalListener、TCPForwarder
- `@MainActor` for：所有 UI（SwiftUI 默认）
- State machine 模型：`@Observable`（iOS 17+）— 若需支持 iOS 16 则用 `ObservableObject` + `@Published` 双轨。**默认 iOS 17+ 单一路径**，不维护双轨（决策 9 隐含）
- Task 隔离：每个 ClientInstance 一个 root Task，子 Task 为 TCP read/write loop

**取消传播**：close ClientInstance → 取消所有子 Task → 关闭所有 socket。

## 8. 错误处理

| 场景 | 处理 |
|---|---|
| Server 不可达 | StatusProbe 标 `down`，UI 灰显，Run 按钮 disable |
| 密码不匹配 | Test Client 5s 后无响应 → Failed，UI 提示 "verify secret matches server" |
| 后端不可达 | TCP connect to backend fails → ClientInstance `failed`，UI 提示 "backend unreachable" |
| WebView 加载失败 | WKWebView `didFail` → WebViewState `loaded` 但 content 是 error page，不影响其他 webview |
| 心跳失败 | 2 次失败 → ClientInstance `stopped`，UI 提示 "reconnect needed" |
| UserDefaults 损坏 | Log.error，启动用空 Store；旧 key 保留供用户恢复（未来功能） |

不抛 fatal error。所有错误 → 状态机变 Failed + UI 文本提示 + 日志。

## 9. 设计系统集成

- 模块 `DesignSystem/` 暴露 `DS.Color`、`DS.Spacing` 等（token 已定义在 `design-system/tokens/`，见 `00-overview.md` 决策 14、17）
- 视图**只**通过 DS 引用 token，**禁止**硬编码 `Color.blue` / `16` 等
- 组件/模式库待 bootstrap（`design-system/components/`、`patterns/`）

## 10. 已知限制 & 假设

- iOS 16+（`NavigationStack`、`.contextMenu`、iOS 17 `.Observable` 兼容路径）
- iPhone：单 webview 同时可见（其他 tab 隐藏状态保留 WKWebView）
- iPad：WKWebView 独立进程，max ~5 实例并发（系统限制）
- 假设 user 同时只在一个 device 配置（无冲突解决）

## 11. 参考

- qtunnel 协议：`qtunnel-server/doc/PROTOCOL.md`
- qtunnel 源码：`qtunnel-server/src/tunnel/cipher.go`（特别是 `secretToKey` off-by-one）
- iOS CommonCrypto：CCCryptor
- SwiftUI docs：`.contextMenu` / `NavigationStack` / `@Observable`
