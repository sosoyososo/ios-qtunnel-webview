# Radius Tokens

iOS 标准圆角。

| Token | 值 | 用途 |
|---|---|---|
| `button` | 8 | 按钮 |
| `card` | 12 | card / 容器 |
| `thumb` | 8 | 缩略图、tab |

## Swift 引用

```swift
RoundedRectangle(cornerRadius: DS.Radius.card)
    .fill(DS.Color.bgSecondary)
```

## 演进规则

- 不引入 4 / 6 / 10 / 16 等"中间值"
- iOS 系统控件圆角由系统决定（如 `.button` border shape），不强行覆盖
