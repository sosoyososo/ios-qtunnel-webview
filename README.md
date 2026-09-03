# qtunnel-ios-web

iOS client for qtunnel encrypted tunnel. SwiftUI, iOS 17+.

> **Spec**: `../docs/specs/2026-09-03-qtunnel-ios-web/00-overview.md`
> **Design system**: `../design-system/MASTER.md`

## Setup

```bash
# 1. Install xcodegen (one-time)
brew install xcodegen

# 2. Generate Xcode project
cd qtunnel-ios-web
xcodegen generate

# 3. Open in Xcode
open Qtunnel.xcodeproj
```

## Structure

| 路径 | 职责 |
|---|---|
| `App/` | App 入口、Info.plist |
| `DesignSystem/` | DS token + 组件库 |
| `Models/` | 纯数据模型（Server / ClientConfig / ...） |
| `Storage/` | UserDefaults 持久化（Store） |
| `Protocol/` | qtunnel 协议层（Cipher / TunnelConnection / Heartbeat） |
| `Networking/` | StatusProbe / LocalListener / TCPForwarder |
| `StateMachine/` | 实体状态机 |
| `UI/` | SwiftUI 视图 |
| `Util/` | Password / ServerCmd / Log |
| `Tests/` | 单元 + 集成测试 |

## Build & Test

```bash
# Generate xcodeproj (每次改 project.yml 后跑一次)
xcodegen generate

# Build via CLI
xcodebuild -project Qtunnel.xcodeproj -scheme Qtunnel -sdk iphonesimulator build

# Run tests
xcodebuild test -project Qtunnel.xcodeproj -scheme Qtunnel -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 引用

- qtunnel 协议：`qtunnel-server/doc/PROTOCOL.md`（含 cipher off-by-one）
- spec：`docs/specs/2026-09-03-qtunnel-ios-web/`
- design tokens：`design-system/tokens/`
