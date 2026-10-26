# qtunnel-ios-web Design System

> Bootstrap 2026-09-03 · 风格基调: iOS Settings.app

## 风格基调

视觉风格对齐 iOS Settings.app：
- `systemGroupedBackground` 系列背景
- `systemBlue` 强调色
- SF Pro 字体
- `.insetGrouped` list 样式
- 4-pt spacing grid

## 目录

| 路径 | 内容 |
|---|---|
| `tokens/color.md` | 颜色 token（含 status 语义色） |
| `tokens/spacing.md` | 间距 token（4-pt grid） |
| `tokens/radius.md` | 圆角 token |
| `tokens/typography.md` | 字体 token（iOS text styles） |
| `components/` | 组件库（待 bootstrap） |
| `patterns/` | 模式库（待 bootstrap） |

## 使用规则

按 `~/.claude/design-system-engine.md`：
- **Token Discipline** (Rule §7)：UI 中禁止裸值；只用 token
- **Reuse First** (Rule §5)：新增 UI 前先查现有 token/component/pattern
- **Controlled Evolution** (Rule §6)：缺资产时调 `ui-ux-pro-max`，只补缺，不重设

## 当前资产

| 类别 | 数量 | 状态 |
|---|---|---|
| Token (color) | 12 | ✅ |
| Token (spacing) | 6 | ✅ |
| Token (radius) | 3 | ✅ |
| Token (typography) | 12 | ✅ |
| Component | 0 | ❌ 缺失 |
| Pattern | 0 | ❌ 缺失 |

## 引用

- spec：`docs/specs/2026-09-03-qtunnel-ios-web/00-overview.md` 决策 14
- iOS HIG：Color / Typography / Materials
