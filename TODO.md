# TODO — qtunnel

项目级需求清单。位置固定,每次会话以本文件为准。

---

## [done] Instance 详情页改造

> 涉及模块:`qtunnel-ios-web` (iOS / Swift)

**目标**:Instance 详情页需要补充两块信息/能力。

- [x] **显示加密方法**
  - 当前 Instance 详情页缺少加密方式(cipher)的展示
  - 需要在该页面以可读形式呈现当前 Instance 所属 ClientConfig 的加密方法(如 `rc4` / `aes-256-cfb`)
  - 视觉样式与 `design-system/` 现有 tokens 保持一致
- [x] **新增「拷贝服务端命令」按钮**
  - 在 Instance 详情页添加一个按钮,点击后把对应的服务端启动命令拷贝到剪贴板
  - 命令字符串复用现有逻辑,与配置创建页面保持完全一致
  - 拷贝成功需要 toast/反馈提示

实现:`UI/InstanceDetailView.swift` 新增 `Section("Config")`(在 Run/Stop 之后、WebViews 之前),含 `LabeledRow("Crypto", value: config.cryptoMethod.displayName)` + 一个 inline 按钮,沿用 `copyLocalAddress()` 的 `UIPasteboard` + 2s 状态翻转 + `UIImpactFeedbackGenerator` 反馈模式。`copyServerCmd()` 通过 `ServerCmd.build` 用与 `ClientConfigEditView.generatedCmd()` 同样的入参(包含硬编码 `backendHost = "127.0.0.1"`、`crypto = cliValue`)。Build 验证:`xcodebuild -destination 'iPhone 16 Pro (18.0)'` → BUILD SUCCEEDED。

---

## 信息源(实现时查阅)

- 服务端命令拼装逻辑 → `qtunnel-ios-web/Util/ServerCmd.swift`
- 加密方法枚举/字段 → `qtunnel-ios-web/Models/CryptoMethod.swift`、`Models/ClientConfig.swift`
- 配置创建页面 UI 参考 → `qtunnel-ios-web/UI/ClientConfigEditView.swift`(这里选了加密方法,命令里也会有)

---

## [done] Instance 导入 / 导出

> 涉及模块:`qtunnel-ios-web` (iOS / Swift)

### 目标
- 把一个 Instance 的完整配置(其绑定的 Server + Config)导出为可移植文本,供他人复制粘贴导入
- 在首页提供「导入」按钮,从剪贴板读取 JSON,校验后一键重建 Instance(自动创建 Server / Config 并绑定)

### 数据格式(采用 JSON, schema v2)

```json
{
  "schema_version": 2,
  "kind": "qtunnel.instance.export",
  "exported_at": "2026-09-11T10:49:00Z",
  "instance": {
    "config_name": "my-config",
    "server": {
      "name": "my-server",
      "host": "1.2.3.4"
    },
    "server_port": 9000,
    "backend_port": 8080,
    "crypto_method": "aes256cfb",
    "password": "your-password"
  }
}
```

字段说明:
- `schema_version` — 整数,版本号,用于将来字段演进时兼容性(当前 v2)
- `kind` — 固定字符串 `qtunnel.instance.export`,import 时作为快速识别
- `exported_at` — ISO8601 时间戳,仅供溯源,import 时不强制校验
- `instance.config_name` — Config 的显示名(对应 ClientConfig.name)。**v1 不带此字段**,import 时用 `host:serverPort` 推导回填
- `instance.server.name` — Server 的显示名
- `instance.server.host` — Server 的 host 或 IP(**去重键**)
- `instance.server_port` — 服务端监听端口(对应 Config.qtunnelPort)
- `instance.backend_port` — 后端服务端口(对应 Config.backendPort)
- `instance.crypto_method` — 加密方法,如 `rc4` / `aes256cfb`
- `instance.password` — 密码,明文

> **Schema 演进**:v1 → v2 新增 `instance.config_name`(原来决定"不导出 instance.name"已被反转,因为 ClientConfig 有 name 字段,跨设备保留它更合理)。v1 payload 仍然接受,导入时用 `<host>:<serverPort>` 推导。

### 导入流程
1. 首页新增「导入」按钮
2. 点击 → 从剪贴板读取文本
3. 校验 JSON 格式与字段完整 → 不通过则提示校验失败
4. 去重:
   - **Server 去重**:`server.host`(host 或 IP)匹配 → 不重建,复用现有
   - **Config 去重**:`server.host` **且** `server_port` 都匹配 → 视为重复配置
     - 命中重复 → 弹窗告知「该配置已存在」,弹窗上提供按钮跳转至对应 Config 详情页(无需新建)
     - 不命中 → 创建 Server(若需要) + Config,自动绑定到新 Instance
5. **Backend Service 端口不参与 Config 去重判断**
6. 导入完成 / 命中重复,无论哪种 → **server / config / instance 列表必须刷新**(同一 Store 的 observable 触发 SwiftUI 重渲即可,无需广播)

### 导出流程
1. 在 Instance 详情页提供「导出」按钮
2. 点击 → **先弹一个风险提示**「内容含明文密码,请勿分享给他人」→ 用户确认后,才把 schema 序列化为 JSON 字符串写入剪贴板,并给成功 tip
3. 写入完成后给一条简短 tip「Exported — 含明文密码,请勿分享」

### 已决定的产品规则
- **导出含 `config_name`** — v2 schema 新增,导入时直接用于 ClientConfig.name;v1 payload 回填 `<host>:<serverPort>`
- **导出强制前置风险提示** — 提示文案包含「明文密码」「请勿分享」;用户必须确认才执行复制
- **导入反馈两种结果**:`success` 或 `duplicate`;两种都必须刷新 server / config / instance 列表

实现:
- 新文件 `qtunnel-ios-web/Util/InstanceExport.swift`:schema v2,`Payload`/`ServerRef`/`Instance` Codable 结构(snake_case keys 直接对齐 schema;`config_name` 在 v2 必填、v1 缺失);`encode(instance:config:server:)` 产 pretty + sorted-keys JSON;`decode(_:)` 走 `JSONDecoder` + 业务字段二次校验,产出强类型 `Parsed`(含 `configName`);`ImportError` 枚举含 8 种情况,每条都有 user-facing 文案。v1 → v2 migration:导入 v1 时用 `<host>:<serverPort>` 作为 Config 名,跟 server.name 区分。
- `UI/InstanceDetailView.swift`:新增 `Section("Share")`(在 WebViews 之后),含一个 `square.and.arrow.up` Export 按钮 → `.alert("Export contains plaintext password")` 风险提示(只有 "Copy Anyway" 才执行复制)→ 走 `InstanceExport.encode` + `UIPasteboard` + 2s 状态翻转 + haptic 反馈。
- `UI/ServerListView.swift`:工具栏 `topBarTrailing` 把导入按钮和 `+` 按钮并排(`[↓] [+]`);`attemptImport()` 读剪贴板 → `InstanceExport.decode` → Server dedup(按 host;不命中就创建并 `env.registerServer` 启 probe)→ Config dedup(按 `(serverId, qtunnelPort)`)→ 命中重复给 `Alert` 提供 "View Config" 跳转 `NavTarget.config(id)` → 不命中就创建 `ClientConfig`(`backendHost` 固定 `127.0.0.1`,`name` 用 `parsed.configName`)+ `env.createInstance(for:)` → success alert。列表刷新走 `@Observable` 自动。
- Build 验证:`xcodebuild -destination 'iPhone 16 Pro (18.0)'` → BUILD SUCCEEDED;同步 `xcrun devicectl device install app` 到 iPad (2)(personal team 8V95JS2XCZ)。
- Real-device signing 注意点:`project.yml` 必须写 `DEVELOPMENT_TEAM: 8V95JS2XCZ`(personal team),否则只 `Sign to Run Locally` 在真机会报 `requires a development team`。
