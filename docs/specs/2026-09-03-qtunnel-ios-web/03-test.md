# 03 — Test

## 1. 测试金字塔

```
       ┌────────┐
       │  E2E   │  ← Golden path (1-2 个)
       ├────────┤
       │ Integ  │  ← Module 组合（5-8 个）
       ├────────┤
       │ Unit   │  ← 每个 module（30-50 个）
       └────────┘
```

目标覆盖率：核心协议 + 状态机 ≥ 90%，其他 ≥ 60%。

## 2. Golden Path（端到端）

唯一必须全通的场景：用户从 0 启动到看见 backend。

### 2.1 前置
- iOS Simulator（iPhone 15 + iPad Pro）
- 本地启动一个 mock backend（HTTP server on `127.0.0.1:8080`，返回 `hello from backend`）
- 本地启动一个 qtunnel-server（`go run` from `qtunnel-server/src/`，listen `:9001`，backend `127.0.0.1:8080`）

### 2.2 步骤
1. 启动 app → P1 ServerList 空
2. tap "+" → P2 输入 `name=Test`, `host=127.0.0.1`, `port=9001` → Save
3. 回到 P1 看到 `Test`，状态点 ◌（unknown）→ 5s 后变 ●（up）
4. tap row → P3 → tap "+" → P4
5. P4 输入 `name=Backend`, 选 `crypto=rc4`, 点 "Generate Password"（生成 32-char）
6. 输入 `backend host=127.0.0.1`, `port=8080` → Save
7. tap "Generate Cmd" → P8 复制命令
8. 启动 mock qtunnel-server with same secret → 终端输出 `qtunnel started`
9. P6 "Test Client" → toast `Test passed (latency Xms)`，instance 回到 `idle`（Test 不留连接，决策 2）
10. P6 "Run" → instance 进入 `running`
11. P6 "Open WebView" → P7 出现 webview，显示 `hello from backend`
12. P7 底栏 tap "+" → 第二个 webview，同样显示 `hello from backend`
13. 关闭 app → 重新启动 → P7 显示两个 webview，状态恢复
14. 长按 P4 "Regenerate" → 确认 → 新 secret → 新 cmd
15. 用新 cmd 重启 qtunnel-server → P6 "Test Client" 仍然 pass

### 2.3 通过判据
- 步骤 3 状态变 up（≤10s）
- 步骤 9 Test pass（≤5s），instance 回到 idle
- 步骤 11 Run 成功，instance 进入 running
- 步骤 12 webview 显示 `hello from backend`
- 步骤 13 两个 webview 同时存在
- 步骤 14 重启后状态恢复
- 步骤 15 重生密码后仍互通

### 2.4 失败信号
- Test 失败 → 检查 secret 是否一致（最常见错误）
- webview 显示 "无法连接" → 检查 mock backend 是否启动 + ATS 例外是否加

## 3. 单元测试

按模块分组，每组列代表性 case（不全列，由 code agent 实施时补全）。

### 3.1 Protocol/

**KeyDerivationTests**
- `test_RC4_keyMatchesGoServer`: 用 `secret="testsecret"`，断言 key = `217df19d942a4a990ebeed63a9832900`（含 off-by-one 末字节 0x00）
- `test_AES_keyMatchesGoServer`: 断言 32-byte key 末字节 0x00
- `test_differentSecretsProduceDifferentKeys`
- `test_emptySecretProducesStableKey`（边界）
- `test_unicodeSecretHandledCorrectly`

**RC4CipherTests**
- `test_encryptDecryptRoundtrip`
- `test_longStreamDoesNotLeakKey`（1MB+ 数据往返）
- `test_keyStateIndependentBetweenEncryptAndDecrypt`

**AES256CFBCipherTests**
- `test_encryptDecryptRoundtrip`
- `test_ivIsFirst16BytesOfKey`
- `test_crossImplementationInterop_GoVsSwift`（用 Go 测试向量）

### 3.2 StateMachine/

**ServerStateTests**
- `test_unknownToUp_onProbeSuccess`
- `test_unknownToDown_onProbeFail`
- `test_upToDown_onProbeTimeout`

**ClientInstanceStateTests**
- `test_idleToHandshaking_onStart`
- `test_handshakingToRunning_onSuccess`（start(short=false)）
- `test_handshakingToFailed_onTimeout`
- `test_runningToStopped_onHeartbeatFail`
- `test_stoppedToHandshaking_onRestart`
- `test_shortStartToIdle_onSuccess`（start(short=true)，连接关闭）
- `test_shortStartToIdle_onFailure`（start(short=true)，连接关闭）

**WebViewStateTests**
- `test_pendingToLoading_onCreate`
- `test_loadingToLoaded_onDidFinish`
- `test_loadedToFocused_onTap`
- `test_focusedToHidden_onCloseButton`

### 3.3 Networking/

**StatusProbeTests**
- `test_returnsUp_whenPortOpen`（mock 一个 TCP listener）
- `test_returnsDown_whenPortClosed`
- `test_returnsDown_onTimeout`

**TCPForwarderTests**
- `test_forwardsBytes_fromLocalToTunnel`
- `test_forwardsBytes_fromTunnelToLocal`
- `test_closesBothSides_onOneSideEOF`

**HeartbeatTests**
- `test_sendsEncryptedByte_everyInterval`
- `test_marksStopped_onTwoConsecutiveFailures`

### 3.4 Util/

**PasswordTests**
- `test_generates32Chars`
- `test_generatesOnlyAlphanumeric`
- `test_twoGenerationsDiffer`

**ServerCmdTests**
- `test_buildsCorrectCommandForRC4`
- `test_buildsCorrectCommandForAES`
- `test_handlesSpecialCharsInSecret`

### 3.5 Storage/

**StoreTests**
- `test_roundtripsAllEntities`
- `test_recoversFromCorruptJSON`
- `test_concurrentWriteIsSafe`（actor 隔离保证）

## 4. 集成测试

### 4.1 Protocol ↔ Networking
- `test_fullTunnelConnection`: 起本地 qtunnel-server，ClientInstance 跑通 → bytes 双向通

### 4.2 StateMachine ↔ UI (ViewInspector)
- `test_instanceDetail_showsRunningUI`
- `test_serverList_showsDownState`

### 4.3 WebView ↔ Tunnel
- `test_webviewLoadsThroughTunnel`: WKWebView load `http://127.0.0.1:port/`，断言 content 是 backend response

## 5. 手动测试场景（Simulator + 真机）

| ID | 场景 | 步骤摘要 | 通过判据 |
|---|---|---|---|
| M1 | iPad 双 webview 重叠 | 开两个 webview，拖到重叠位置 | zindex 切换正常 |
| M2 | 后台 → 前台 | Run Client 后切到后台 30s，再回前台 | 连接保持（不重连） |
| M3 | 飞行模式 | Run Client 后开飞行模式 | StatusProbe 标 down |
| M4 | iPad 多 webview 拖动 | 拖 webview 边缘 | 流畅（60fps） |
| M5 | iPhone 单手切换 | 一只手切 tab | 单手可达 |
| M6 | 长按菜单 | 长按 webview tab | context menu 弹出 |
| M7 | Reset | About → Reset | Store 清空，回到 P1 空状态 |

## 6. 已知不可测 / Out of scope

- NetworkExtension / 后台长连接（决策 10：仅前台）
- 性能压测（YAGNI）
- 安全审计（明文密码、no auth 是设计选择）
- HTTPS backend（决策 6：仅 HTTP）
- 多设备同步（YAGNI）

## 7. 参考

- Golden path 设备：iPhone 15 / iPad Pro 12.9" (M2)
- mock backend：`python3 -m http.server 8080`
- qtunnel-server 测试代码：`qtunnel-server/src/tunnel/*_test.go`（可借鉴 cipher 测试向量）
