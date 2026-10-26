# Patterns

待 bootstrap。当前无 pattern。

## Bootstrap 候选

- `SettingsList` — iOS Settings 风格分组列表
- `FormEdit` — 创建/编辑表单（form + save button）
- `DetailView` — 详情页（status + actions + info sections）
- `WebViewCanvas` — 多 webview 容器（iPhone / iPad 双形态）
- `ConfirmAlert` — 二次确认弹窗（含 regenerate password 用例）

## 演进规则

按 `~/.claude/design-system-engine.md` Rule §8 (Pattern Extraction)：
- 多个屏幕共用同一结构时提取为 pattern
- 提取前确认复用 ≥ 2 处
- pattern 与 component 的区别：pattern = 多个 component 的组合 + 数据流
