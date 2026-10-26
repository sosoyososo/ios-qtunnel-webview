# 02 — Product

## 1. 页面列表

| 页面 | 入口 | 主要内容 |
|---|---|---|
| P1. ServerList | App 启动 | 所有 server 列表，含状态点（up/down） |
| P2. ServerEdit | P1 tap "+" 或 row | 新增/编辑 server（name, host） + 实时 DNS 探活 |
| P3. ClientConfigList | P1 row tap | 隶属于该 server 的 clientConfig 列表 |
| P4. ClientConfigEdit | P3 tap "+" 或 row | 新增/编辑 clientConfig（name, qtunnelPort, crypto, secret, backendPort） |
| P5. ClientInstanceList | P3 row tap | 隶属于该 clientConfig 的 instance 列表 |
| P6. InstanceDetail | P5 row tap | 单 instance 详情 + Run/Test/Open WebView 按钮 + 心跳信息 |
| P7. WebViewCanvas | P6 "Open WebView" 或独立 tab | 多 webview 容器（iPhone 全屏切换 / iPad 浮动） |
| P8. ServerCmdModal | P4 "Generate Cmd" 按钮 | 显示完整 server 启动命令 + Copy |
| P9. RegeneratePasswordAlert | P4 "Regenerate" 按钮 | 二次确认 modal |
| P10. About | P1 footer 或 toolbar | 版本、文档链接、reset 按钮 |

## 2. 页面布局（iPhone）

### P1. ServerList
```
┌──────────────────────────────────┐
│ Servers                    [+]   │
├──────────────────────────────────┤
│ ● VPS-A                          │  ● = up, ○ = down, ◌ = unknown
│   qj.example.com                 │
├──────────────────────────────────┤
│ ○ VPS-B                          │
│   qj2.example.com                │
├──────────────────────────────────┤
│                                  │
├──────────────────────────────────┤
│ About • Reset                    │
└──────────────────────────────────┘
```
- `.listStyle(.insetGrouped)`
- tap row → P3
- tap "+" → P2
- 长按 row → context menu（Edit / Delete / Probe Now）

### P3. ClientConfigList
```
┌──────────────────────────────────┐
│ < Servers    VPS-A          [+] │
├──────────────────────────────────┤
│ Admin                            │
│   RC4 • qj.example.com:9001→:8080│
├──────────────────────────────────┤
│ Dashboard                        │
│   AES256-CFB • ...→:9090         │
└──────────────────────────────────┘
```
- subtitle 格式：`crypto • <host>:<qtunnelPort>→:<backendPort>`

### P5. ClientInstanceList
```
┌──────────────────────────────────┐
│ < Admin                     [+] │
├──────────────────────────────────┤
│ ● instance #1                    │
│   local :54321  • running 3m     │
├──────────────────────────────────┤
│ ○ instance #2                    │
│   local :0       • idle          │
└──────────────────────────────────┘
```

- 顶部 nav title = clientConfig.name（如 "Admin"）
- 默认 1 个 instance；tap "+" 创建 instance #2（用于并发规避 head-of-line blocking）

### P6. InstanceDetail
```
┌──────────────────────────────────┐
│ < instance #1                    │
├──────────────────────────────────┤
│ Status                           │
│   ● Running • uptime 12m         │
│   local 127.0.0.1:54321          │
│   remote qj.example.com:9001     │  ← 从 cfg.qtunnelPort 来
│   heartbeat 2m ago (next 3m)     │
├──────────────────────────────────┤
│ [    Stop    ]                   │
│ [   Test   ] [ Reconnect ]       │
│ [ Open WebView ]                 │
└──────────────────────────────────┘
```

### P7. WebViewCanvas（iPhone）
```
┌──────────────────────────────────┐
│ Admin[1]               ← 🏠 → ✕ │  ← 顶部固定，title + back/home/forward/close
├──────────────────────────────────┤
│                                  │
│   [WKWebView content]            │
│                                  │
│                                  │
├──────────────────────────────────┤
│ [1●] [2] [3] [+]                 │  ← 底部 tab strip
└──────────────────────────────────┘

● = current focus
+ = open new webview (round-robin to instance)
长按 tab → context menu（Bring to Front / Close / Edit Config）

← back：WKWebView.goBack()（无历史时灰显）
🏠 home：webView.load(homeURL = http://127.0.0.1:{localPort}/)
→ forward：WKWebView.goForward()（无后续时灰显）
✕ close：删除 webview，回到 tab strip
```

### P8. ServerCmdModal
```
┌──────────────────────────────────┐
│ Server Start Command         [✕] │
├──────────────────────────────────┤
│ Run this on your VPS:            │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ qtunnel -listen=:9001 \      │ │
│ │   -backend=127.0.0.1:8080 \  │ │
│ │   -crypto=rc4 \             │ │
│ │   -secret=a1b2c3d4...        │ │
│ └──────────────────────────────┘ │
│                                  │
│         [ Copy Command ]         │
└──────────────────────────────────┘
```

## 3. 页面布局（iPad）

P1-P6 沿用 `NavigationSplitView`：侧栏是 ServerList，详情区是 ClientConfigList/Edit。

P7 改动：
- WebView 是浮动卡片（无 size handle），每张卡都有 top/bottom chrome
- 多 webview 可拖动至任意位置
- zindex 由"最后 tap"决定，▲▽ 显式覆盖

```
iPad P7:
┌──────────────────────────────────────────────┐
│ [+ New Webview]   [Cleanup]      [Settings]   │  ← top toolbar
├──────────────────────────────────────────────┤
│                                              │
│  ┌─────────────────────┐                     │
│  │ Admin[1]      ▲▽✕  │                     │
│  │ ─────────────────── │                     │
│  │  [content]          │                     │
│  │ ─────────────────── │                     │
│  │ [1●][2][3][+]       │                     │
│  └─────────────────────┘                     │
│                                              │
│            ┌─────────────────┐                │
│            │ Admin[2]  ▲▽✕  │                │
│            │ ─────────────── │                │
│            │  [content]      │                │
│            │ [1][2●][3][+]   │                │
│            └─────────────────┘                │
└──────────────────────────────────────────────┘
```

## 4. 关键操作流程

### Flow A. 首次配置
1. P1 tap "+" → P2 输入 `name`, `host` → DNS 实时探活显示 ●/○
2. P2 Save → P3 自动显示新 server 的 ClientConfigList → tap "+" → P4
3. P4 输入 `name`, `qtunnelPort`（server 监听端口）, 选 `crypto`, 点 "Generate Password"（自动生成 32-char）
4. P4 输入 `backendPort`（host 默认 127.0.0.1）
5. P4 Save → 自动回到 P3
6. P4（或 P3 row tap → P5）→ "Generate Cmd" → P8 显示命令
7. Copy → SSH 到 VPS → 运行
8. 回到 P1 → row 显示 ● up（10s 内 DNS resolve 通过即视为 up）

### Flow B. 启动 Client + 打开 WebView
1. P3 row tap → P5（自动创建 instance #1）
2. P5 row tap → P6
3. P6 "Run" → instance 进入 running
4. P6 "Open WebView" → P7 显示首个 webview（title = "Admin[1]"）
5. 在 P7 底栏 tap "+" → 第二个 webview（title = "Admin[2]"）

### Flow C. 改密码
1. P4 "Regenerate" → P9 alert
2. 确认 → 重新生成 secret → Store 更新
3. 自动展示 P8 新命令
4. Copy → 用户重新跑 server

### Flow D. Test Client（5s 内出结果）
1. P6 "Test" → ClientInstance.start(short=true)
2. 状态：`handshaking` (5s timeout)
3. 成功 → toast "Test passed (latency Xms)"，连接关闭，instance 回到 `idle`
4. 失败 → toast "Test failed: <reason>"，连接关闭，instance 回到 `idle`

## 5. 设计 token 引用

```swift
DS.Color.bgGrouped         // 背景
DS.Color.accent            // 强调（按钮、链接）
DS.Color.statusUp          // ●
DS.Color.statusDown        // ○
DS.Color.labelPrimary      // 标题、正文
DS.Color.labelSecondary    // 副标题

DS.Spacing.m (12)          // list row 内 padding
DS.Spacing.l (16)          // section 间隔
DS.Spacing.xl (20)         // screen edge padding

DS.Radius.card (12)        // card 圆角
DS.Font.title              // section title
DS.Font.body               // 正文
DS.Font.caption            // 副信息
DS.Font.mono               // 命令文本
```

完整 token 见 `DesignSystem/DS.swift`，具体值待设计系统 skill 确认后落地。

## 6. 已知交互细节

- **iPhone 上 webview 切换**是瞬时（无需加载，WKWebView 保活）
- **iPad 上 webview 拖动**：自由位置，无吸附效果（保持最大灵活性，决策 12）
- **状态点**颜色：up=绿、down=红、unknown=灰；色盲友好（形状辅助 ● ○ ◌）
- **错误提示**用 toast（不阻塞，3s 自动消失），不打断操作

## 7. 参考

- 设计 token 草案：00-overview.md 决策 14
- iOS Settings.app：Apple HIG
- SwiftUI：`NavigationStack` / `.contextMenu` / `.listStyle(.insetGrouped)`
