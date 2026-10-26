# Spacing Tokens

4-pt grid。所有 UI 间距必须是 4 的倍数，禁止裸值。

| Token | 值 | 用途 |
|---|---|---|
| `xs` | 4 | icon 内边距、tight inline gap |
| `s` | 8 | 控件内边距（按钮、chip） |
| `m` | 12 | list row 内 padding、card padding |
| `l` | 16 | section 间距、screen 内 padding |
| `xl` | 20 | screen edge padding（iPhone 标准） |
| `xxl` | 24 | 大 section 间距 |

## Swift 引用

```swift
DS.Spacing.m   // 12
DS.Spacing.l   // 16

// 常用 padding
VStack(spacing: DS.Spacing.l) {
    // section 内
}
.padding(.horizontal, DS.Spacing.xl)
```

## 演进规则

- 不引入 14 / 18 / 22 等"中间值"
- 超过 24 的间距用 `xxl * n` 或新建 token（新建需说明业务原因）
