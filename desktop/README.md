# CandySign Desktop · GPUI Kit 原型

独立的 Rust 桌面交互原型，使用 [GPUI Kit](https://github.com/longbridge/gpui-kit) 0.9.0。现有 SwiftUI 应用、MCP 客户端、Keychain 和打包流程不变，两者可以分别运行。

**所有功率、设备和曲线均为合成演示数据。此原型没有网络请求，也不会读取或修改真实设备。**

## 运行

安装当前 stable Rust 工具链。在仓库根目录执行：

```sh
cargo run --locked --manifest-path desktop/Cargo.toml
```

macOS 需要包含 SDK 的 Xcode；Windows 使用 MSVC Rust 工具链和 Visual Studio C++ Build Tools。Linux 需要可用的图形会话及 GPU/Vulkan 驱动；Ubuntu 24.04 的构建依赖可安装：

```sh
sudo apt-get update
sudo apt-get install -y gcc g++ clang pkg-config libfontconfig-dev libwayland-dev \
  libxkbcommon-x11-dev libx11-xcb-dev libssl-dev libzstd-dev libasound2-dev \
  libvulkan1 vulkan-validationlayers
```

可选参数放在 Cargo 的 `--` 后面：

```sh
cargo run --locked --manifest-path desktop/Cargo.toml -- --window
cargo run --locked --manifest-path desktop/Cargo.toml -- --no-tray
```

- `--window`：macOS 也使用普通窗口，不随失焦关闭；Windows/Linux 默认如此。
- `--no-tray`：不创建托盘，关闭最后一个窗口后退出，适合没有托盘宿主的桌面环境。
- `--help`：查看参数。

## 已实现

- 五端口总览；区分未连接、已连接未充电和充电中；一次展开一个端口，显示电气参数和明确标注的合成曲线。
- 面板精简重复说明，功率使用等宽数字和次级单位；过期/离线直接在总功率旁标注“上次读数 · 非实时”。曲线标注功率范围及样本 1–7，不伪造真实时间范围。
- 刷新演示在两组样本间切换，同时更新托盘读数。
- 设置窗口单实例，语言、外观和演示状态使用分段选择。语言默认跟随启动时的系统语言，也可显式选择简体中文/English；非中文系统回退英文。
- 过期与离线保留旧读数并提示；托盘显示 `— W`，不冒充实时数据。
- macOS 菜单栏显示演示总功率；点击普通窗口的关闭按钮或按 Escape 后，可从菜单栏重新打开紧凑浮层。浮层按实际排版高度适配内容，不按语言或连接状态累加猜测高度；点击外部关闭，屏幕空间不足时正文可滚动，底部操作保留。
- Windows/Linux 使用普通任务栏窗口；托盘图标及提示、右键菜单提供打开、设置与退出入口。Linux 使用 StatusNotifierItem，不依赖 GTK 托盘。
- 刷新、设置、退出快捷键：macOS 为 `Command-R`、`Command-,`、`Command-Q`，Windows/Linux 为对应的 `Ctrl` 组合；Escape 关闭当前窗口。

Windows 关闭窗口后继续保留托盘进程。Linux 可能没有 SNI 宿主，即使注册托盘成功也不一定显示图标，因此默认打开普通窗口，关闭最后一个窗口即退出。GNOME 等环境可使用 `--no-tray`；本阶段不承诺所有 Linux 桌面都有托盘入口。

## 验证与范围

本地验证环境：Apple Silicon macOS。Windows/Linux 已提供对应的平台分支及三系统 CI 构建配置，**尚未在这两个系统上实际构建或运行验证**，不是已发布的三平台版本。

```sh
cargo fmt --manifest-path desktop/Cargo.toml --check
cargo clippy --locked --manifest-path desktop/Cargo.toml --all-targets -- -D warnings
cargo build --locked --manifest-path desktop/Cargo.toml
swift test
```

原生交互检查：刷新后总功率 83.6 → 80.2 W；重复打开设置和在设置中重复按设置快捷键不创建第二个窗口；关闭后可重开；切换语言和外观同步到面板；过期/离线时托盘隐藏实时功率；浮层展开/收起和外部点击；无托盘模式关闭最后一个窗口退出。

以下尚未移植：真实 MCP/JSON-RPC/SSE、只读工具白名单、安全凭据存储、定时采集、真实历史分段、睡眠/唤醒、持久化偏好和安装包/签名。设置仅影响本次进程，不读取或保存 SwiftUI 的配置。

## 结构

- `src/main.rs`：演示状态、窗口生命周期、快捷键、托盘事件分发。
- `src/ui.rs`：GPUI Kit 面板、端口展开、曲线和设置。
- `src/tray.rs`：原生托盘、菜单事件和 macOS 浮层定位。

下一阶段再把现有 Swift 客户端的协议与安全约束迁到独立 Rust 核心；本次不建立尚无真实调用方的核心抽象。
