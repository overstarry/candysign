# CandySign

macOS 菜单栏充电监控程序，使用 Swift + SwiftUI，直接读取小电拼的真实 MCP 数据。首版仅查询，不修改充电策略、端口供电或设备设置。

## 运行

需要 macOS 14+、Swift 6.2+ 和包含 macOS SDK 的 Xcode。当前已在 Apple Silicon 上构建并验证；Intel 尚未验证。

```bash
swift test
bash scripts/build-app.sh
open dist/CandySign.app
```

也可以用 Xcode 打开 `Package.swift`。实际使用建议运行打包后的 `.app`，让菜单栏行为和 Keychain 身份保持一致。产物采用本地 ad-hoc 签名，尚未做 Developer ID 签名和公证。

首次打开后进入 Settings，粘贴 HTTPS MCP 地址。地址仅保存在 macOS Keychain，不进入 UserDefaults 或仓库。显示名称可以自行修改，清空后恢复默认名称。

首次运行会打开设置窗口。调试构建额外提供复用同一面板的预览窗口和深色外观切换，用于界面验证；Release 不包含这些调试入口。

```bash
bash scripts/build-app.sh debug
```

## 首版功能

- 菜单栏展示总输出功率；点开原生面板查看五端口状态。
- 每 30 秒采集一次，支持手动刷新。型号和固件等信息每 5 分钟刷新。
- 分开显示连接状态与充电状态，不用低功率推断充满。
- 点击端口展开电压、电流、快充协议、温度档位和功率曲线。
- 曲线最多保留本次运行的最近一小时、每口 240 个样本；退出后清空。
- 连接变化或超过 75 秒的采样间隔会切断曲线。错误保留最后读数并明确标注；不会把失败当成零功率。
- Mac 睡眠时取消采集；唤醒后重新读取。
- 简体中文／英文界面，覆盖状态、错误、设置与辅助功能标签。
- 系统深浅色、键盘快捷键：刷新 `Command-R`、设置 `Command-,`、退出 `Command-Q`。

功率条表示输出相对于额定总功率，不是电池电量。MCP 地址中的路径包含访问凭据，请勿放入截图或版本库。第三方服务器返回的原始错误文本不会直接显示或记录，避免带出地址。

## 结构

- `Sources/CandySignCore`：设备数据、限长内存历史、MCP JSON-RPC / JSON / SSE 客户端及中英文语言资源。
- `Sources/CandySignApp`：SwiftUI 面板与设置、Keychain、采集任务及休眠恢复。
- `Sources/CandySignProbe`：使用同一客户端的只读实机验证程序，从标准输入接收地址，不输出地址。
- `Tests/CandySignCoreTests`：单位换算、位图、SSE、错误处理、会话恢复、只读限制和历史边界。
- `Tests/CandySignAppTests`：没有新网络响应时的数据到期、快照替换取消旧到期任务、已过期快照。

客户端仅允许六个读取工具。网络请求在主线程外读取、复用同一连接池、拒绝重定向、使用正常 TLS 校验，并限制超时及响应大小。服务器会话失效时只对读取请求重新初始化并重试一次；每轮采集（连接或唤醒）使用新的客户端会话。

## 实机验证

开发者已有 Codex 设备配置时，可以运行（应用本身不读取 Codex 配置）：

```bash
python3 scripts/check-live.py
```

该脚本在内存中读取 `~/.codex/config.toml`（或 `CODEX_HOME`），经标准输入传给探测程序。不会把凭据写入文件或命令行参数，也不会修改设备。

## 当前范围

支持简体中文和英文，默认跟随 macOS 的应用语言，未支持的语言回退到英文。设备名称优先使用设备提供的本地化名称；未知协议名称保留原文。没有开机启动、持久化历史、设备控制、后台定时规则或电池健康诊断。应用退出和 Mac 睡眠期间不会监控；30 秒采样也不是电气瞬态测量仪器。由于当前设备未提供可靠的历史时间轴，首版不会用设备缓存伪造时间曲线。

## 应用图标

`Resources/AppIcon-v1.png` 为内置 imagegen 生成的透明原图，完整提示词保存在同目录的 `AppIcon-v1.prompt.txt`。`AppIcon-v1.icns` 已接入应用包；需要重新导出各尺寸时运行 `bash scripts/build-icon.sh`。菜单栏仍使用适合小尺寸和系统深浅色的单色 SF Symbol。
