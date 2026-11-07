# CandySign

小电拼充电监控的跨平台桌面原型，使用 Rust + GPUI Kit，面向 macOS、Windows 和 Linux。

**当前仅使用演示数据，尚未接入真实 MCP，不会读取或修改设备。** Swift 实现及其测试、构建和实机探测流程已移除；真实连接、安全凭据存储、定时采集和睡眠恢复尚未移植到 Rust。

## 运行

安装 stable Rust 工具链；macOS 需要包含 SDK 的 Xcode。Windows/Linux 的依赖与平台差异见 [`desktop/README.md`](desktop/README.md)。当前仅在 Apple Silicon macOS 验证，Windows/Linux 待实机验证。

```sh
cargo run --locked --manifest-path desktop/Cargo.toml
```

可通过 `-- --window` 使用普通窗口，通过 `-- --no-tray` 禁用托盘。

## 当前功能

- 托盘入口、五端口总览、端口详情和合成演示曲线。
- 手动刷新在两组演示读数间切换；支持模拟过期与离线状态。
- 简体中文／English、跟随系统／浅色／深色外观；设置仅影响本次运行。
- 刷新、设置与退出快捷键；macOS 使用菜单栏浮层，Windows/Linux 使用普通窗口。

## 结构

- `desktop/`：Rust + GPUI Kit 桌面原型及 Cargo 配置。
- `.github/workflows/desktop.yml`：三平台格式、Clippy、构建与命令行检查。
- `Resources/`：保留的应用图标及生成提示词，当前未接入 Rust 安装包。
- `DESIGN.md`、`VALIDATION.md`：旧版设计与验证的历史记录，不代表当前原型的能力。

## 开发检查

```sh
cargo fmt --manifest-path desktop/Cargo.toml --check
cargo clippy --locked --manifest-path desktop/Cargo.toml --all-targets -- -D warnings
cargo build --locked --manifest-path desktop/Cargo.toml
cargo run --locked --manifest-path desktop/Cargo.toml -- --help
```

## 应用图标

`Resources/AppIcon-v1.png` 为生成的透明原图，完整提示词保存在同目录的 `AppIcon-v1.prompt.txt`。保留 `AppIcon-v1.icns`；需要重新导出各尺寸时运行 `bash scripts/build-icon.sh`（仅 macOS）。
