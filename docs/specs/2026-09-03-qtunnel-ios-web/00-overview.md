# qtunnel-ios-web — Overview

> iOS client app for the qtunnel encrypted tunnel. SwiftUI, iOS 16+.
> Date: 2026-09-03

## Index

| File | Scope |
|---|---|
| `00-overview.md` | 本文件 — 决策日志 + 范围 |
| `01-architecture.md` | 状态机、模块、协议层、并发、数据流 |
| `02-product.md` | 页面列表、布局、操作流程、iPhone vs iPad |
| `03-test.md` | Golden path、测试金字塔、用例 |

## 模型层次

```
Server (VPS 上 qtunnel-server 的 host/IP，无端口)
  └── ClientConfig [1:N]   (iOS 端配置条目：qtunnel 端口、crypto、secret、backend 端口)
        └── ClientInstance [1:N, default 1]   (iOS qtunnel-client 长连接 TCP)
              └── WebView [1:N]               (WKWebView)
```

**Server 只承载 host**：qtunnel-server 的实际监听端口由 ClientConfig.qtunnelPort 持有。
不同 backend 可以跑在同一个 server 的不同端口上，所以 port 属于 Config 而非 Server。

每个 ClientConfig 自动关联一个 ClientInstance。多个 ClientInstance 用于规避 head-of-line blocking（qtunnel-server 不做 mux）。

## 决策日志（2026-09-03 brainstorming）

| # | 决策 | 值 | Why |
|---|---|---|---|
| 1 | WebView→tunnel 模型 | Per-config 本地端口（random） | 与 qtunnel-server 1:1 对齐，简单 |
| 2 | Test Client 语义 | 短握手验证（≤5s） | 出错定位快 |
| 3 | Run Client 语义 | 长连接 + 心跳 | 维持活跃，绕开 30min idle timeout |
| 4 | WebView 身份 | 1 clientConfig → N webviews | 同 backend 多 tab |
| 5 | Server 状态检测 | DNS resolve + NWPath（无端口可用） | Server 不带端口 → 无法 TCP probe；DNS 解析 + 网络可达即视为 up |
| 6 | WebView→backend 协议 | `http://127.0.0.1:R/`（ATS local） | 原生 WKWebView，HTTP only |
| 7 | 密码存储 | UserDefaults 明文 | 符合"不用 keychain" |
| 8 | 密码生成 | 32 chars `[a-z0-9]` | 命令行友好 + 安全 |
| 9 | App nav | Settings 风格 list + WebView canvas | iOS 原生 |
| 10 | 后台模式 | 仅前台 | 简化，无 entitlement |
| 11 | iPhone 布局 | 单 webview 全屏 + 底部 tab strip | 单手可用 |
| 12 | iPad 布局 | 自由浮动（位置 + zindex，无 size 无 grid） | 最大操作灵活性 |
| 13 | 长按交互 | iOS `.contextMenu` + swipe 快捷 | 标准 iOS 模式 |
| 14 | 设计 token | iOS Settings 风格（grouped bg、system blue、SF Pro） | 用户指定 |
| 15 | WebView chrome | top: title + ←🏠→✕（back/home/forward/close），bottom: tab strip | 用户指定 |
| 16 | 文档结构 | 1 主 spec + 4 子文件 | 用户指定 |
| 17 | Design system | 已初始化 `design-system/`（bootstrap 2026-09-03） | 用户选 A |
| 18 | RC4 PRGA keystream 索引 | 用 **s[i]+s[j]**（值）非 i+j（位置） | 与 Go `crypto/rc4` 对齐；bug fix 2026-09-04 |

## 范围

### In scope
- iOS 17+ SwiftUI app（单一路径，不维护 iOS 16 双轨）
- qtunnel 协议 RC4 + AES256-CFB
- 多 server、多 clientConfig、多 clientInstance（默认 1/Config）、多 webview
- 本地端口动态分配
- 心跳保活（5min 间隔）
- DNS 解析 + NWPath 状态探测（10s 间隔）
- WebView 持久化（标题、tab、instance 绑定）
- iPhone + iPad 自适应布局
- iOS Settings 风格设计 token

### Out of scope (YAGNI)
- HTTPS backend 支持（仅 HTTP）
- 密码加密存储（明文 UserDefaults）
- iCloud 同步
- 数据导入/导出
- App icon / splash screen 设计
- NetworkExtension / always-on VPN
- 后台模式（Run Client 仅前台）
- 国际化（仅英文 + 简体中文）
- 性能基准 / 压力测试
- 安全审计

## 引用

- qtunnel 协议（cipher off-by-one 等细节）：`qtunnel-server/doc/PROTOCOL.md`
- qtunnel-server 源码：`qtunnel-server/src/tunnel/`
- App 规格草案：`qtunnel-server/doc/APP_SPECIFICATION.md`（已废，本 spec 取代）

> 路径说明：以上 `qtunnel-server/` 前缀指**工作区同级的独立仓库**
> （github.com/sosoyososo/qtunnel），不在本仓库内；
> 本 spec 与 `design-system/` 内的路径均为本仓库内相对路径。
