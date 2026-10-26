# Typography Tokens

iOS 标准 text styles + monospaced variant。所有字号必须使用 token，禁止裸 `.font(.system(size:))`。

| Token | iOS API | 用途 |
|---|---|---|
| `largeTitle` | `.largeTitle` | screen title |
| `title` | `.title` | section header（大） |
| `title2` | `.title2` | section header（中） |
| `title3` | `.title3` | card title |
| `headline` | `.headline` | list row 标题 |
| `body` | `.body` | 正文 |
| `callout` | `.callout` | 强调正文 |
| `subhead` | `.subheadline` | 副标题 |
| `footnote` | `.footnote` | 注释、metadata |
| `caption1` | `.caption` | 状态文字 |
| `caption2` | `.caption2` | 极小说明 |
| `mono` | `.system(.body, design: .monospaced)` | server start cmd 等命令文本 |

## Swift 引用

```swift
Text("Servers").font(DS.Font.title2)
Text(server.host).font(DS.Font.caption1)
Text(serverCmd).font(DS.Font.mono)
```

## 演进规则

- 不引入新字号（如 `.system(size: 17)` 等自定义）
- 字重只在 token 内部调整；外部用 token 名
- `mono` 是唯一非 SF Pro 的字体（用于命令行文本）；其他场景禁用
