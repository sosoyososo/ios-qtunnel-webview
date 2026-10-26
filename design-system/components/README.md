# Components

待 bootstrap。当前无 component。

## Bootstrap 候选（实施时按需新增）

- `DSListRow` — list row 容器（icon + title + subtitle + accessory）
- `DSCard` — card 容器（圆角 + bgSecondary + padding）
- `DSButton` — 主按钮 / 次按钮
- `DSToast` — 非阻塞提示
- `DSServerCmdCard` — 服务端命令展示卡（含 Copy 按钮）
- `DSWebViewChrome` — webview 顶部 title bar + 底部 tab strip

## 演进规则

按 `~/.claude/design-system-engine.md` Rule §5 (Reuse First) 和 Rule §6 (Controlled Evolution)：
- 新增 component 前先查本目录 + `patterns/`
- 缺什么补什么，不批量生成
- 每个 component 单独一个 md 文件，包含：用法、API、变体、anti-patterns
