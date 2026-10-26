# Color Tokens

iOS Settings.app 风格。所有颜色都是 iOS 系统色的语义包装，自动支持 dark mode / dynamic type / Increase Contrast。

## Background

| Token | 语义 | iOS API | 用途 |
|---|---|---|---|
| `bgGrouped` | 主分组背景 | `Color(.systemGroupedBackground)` | list root / screen background |
| `bgSecondary` | 次级分组背景 | `Color(.secondarySystemGroupedBackground)` | list row / card |
| `bgTertiary` | 三级分组背景 | `Color(.tertiarySystemGroupedBackground)` | nested element |

## Label

| Token | 语义 | iOS API | 用途 |
|---|---|---|---|
| `labelPrimary` | 主文本 | `Color(.label)` | 标题、正文 |
| `labelSecondary` | 次要文本 | `Color(.secondaryLabel)` | 副标题、说明 |
| `labelTertiary` | 三级文本 | `Color(.tertiaryLabel)` | placeholder、辅助 |

## Accent

| Token | 语义 | iOS API | 用途 |
|---|---|---|---|
| `accent` | 强调色 | `Color(.systemBlue)` | 按钮、链接、focus |

## Separator

| Token | 语义 | iOS API | 用途 |
|---|---|---|---|
| `separator` | 分隔线（透明背景上） | `Color(.separator)` | list 内分隔 |
| `separatorOpaque` | 分隔线（不透明背景上） | `Color(.opaqueSeparator)` | card 内分隔 |

## Status

| Token | 语义 | iOS API | 用途 |
|---|---|---|---|
| `statusUp` | 在线 | `Color(.systemGreen)` | server 状态点 |
| `statusDown` | 离线 | `Color(.systemRed)` | server 状态点 |
| `statusUnknown` | 未知 | `Color(.systemGray)` | 未探 |

## Swift 引用

```swift
// 通过 DS.Color 命名空间
DS.Color.bgGrouped
DS.Color.labelPrimary
DS.Color.accent
DS.Color.statusUp
```

## 演进规则

- 新增 token 必须有 iOS 系统色对应（不引入自定义 hex）
- 状态色仅增不删（up / down / unknown 三色足够；不加 warning / busy 等）
- 业务色（红绿状态）必须配合形状（●○◌），不能仅靠颜色（色盲友好）

## 引用

- iOS HIG：https://developer.apple.com/design/human-interface-guidelines/color
- spec：01-architecture §9
