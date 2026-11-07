---
name: CandySign
description: Compact native macOS charging monitor
typography:
  total-output:
    fontFamily: "System Rounded"
    fontSize: "30pt"
    fontWeight: 600
spacing:
  text-stack: "4pt"
  detail-stack: "10pt"
  section-stack: "12pt"
  panel-inset: "20pt"
components:
  charger-panel:
    width: "390pt"
  settings-window:
    width: "490pt"
  power-history:
    height: "80pt"
---

# Design System: CandySign

> 历史记录：本文件描述已移除的 SwiftUI 版本，保留供设计参考，不代表当前 Rust 原型的实现。当前能力与运行方式见 `desktop/README.md`。

## Overview

**Creative North Star: "CodexBar 式原生状态面板"**

沿用用户已确定的系统菜单栏风格：紧凑、克制、以读数为中心。系统字体、原生材质和细分隔线组织信息；总功率先于端口读数，设备详情在原位展开。

本文件记录已实现的 SwiftUI 界面。规范依据是 `Sources/CandySignApp/ChargerPanel.swift`、`SettingsView.swift` 和 `CandySignApp.swift`。动态系统颜色、语义字号和系统控件外观保留原生语义，不转换成固定网页色值或样式。

**Key Characteristics:**

- 系统深浅色与原生材质。
- 紧凑纵向端口行和稳定的数字对齐。
- 颜色辅助状态，文字承载含义。
- 详情和本次运行的曲线原位展开。

## Colors

界面使用 SwiftUI 自适应语义颜色；没有自定义品牌色板或固定明暗主题色值。

- `.primary`：主要读数、连接状态文字、充电状态文字、错误与设置结果文字。
- `.secondary`：说明、容量、时间、非充电状态、协议与温度模式等辅助信息。
- `.orange`：设备符号、异常状态符号、功率曲线，以及容量进度条请求的系统 tint。
- `.green`：连接成功的符号；成功状态文字仍使用 `.primary`。

系统控件可能根据外观与激活状态调整实际呈现。浅色预览中的容量条呈灰色，深色预览呈橙色；不得据此另建固定浅色进度条色值。

**The State Text Rule.** 状态不能仅靠颜色识别。重要状态文字使用主文本色；彩色符号仅辅助识别连接成功或异常。

## Typography

正文使用系统字体与 SwiftUI 的 `.headline`、`.callout`、`.caption`、`.caption2` 语义样式，不指定网页字体或人为行高。

- 总输出使用 frontmatter 的 `total-output` 样式与 `.monospacedDigit()`，作为首要数字。
- 设备名使用 `.headline`；设备型号使用 `.caption` 和次级文本色。
- 端口名使用 rounded、semibold 的 `.callout`；设备名使用 medium 的 `.callout`。
- 端口功率使用 semibold 的 `.callout` 与等宽数字；状态、协议与电气参数使用 `.caption`。
- 曲线时间端点与采样范围说明使用 `.caption2`。
- 时间、功率、电压和电流使用等宽数字，避免刷新时的数字宽度跳动。

总功率与端口功率使用相同格式化规则：通常一位小数，正数且小于 0.1 W 时显示三位小数。缺失端口读数显示 `— W`。

## Layout

菜单栏入口采用 `MenuBarExtra` 的 `.window` 样式。面板宽度、设置窗口宽度和曲线高度以 frontmatter 为准，单位均为原生逻辑点；面板与设置窗口的高度都随内容变化。

面板从上至下是设备标题与连接状态、总输出与容量条、端口列表、温度模式与版本、刷新与设置/退出操作。主要区域采用统一的 `panel-inset`。首屏保持五个端口的纵向阅读顺序。

端口列表不设固定高度也不滚动，展开详情时面板整体变高，避免详情被裁切。一次展开一个端口，详情留在对应行下方，不切换页面。端口行上下各留 11 pt（行内 7 pt，加按钮样式的 4 pt）；端口标签列宽 30 pt，行内间距 10 pt；详情左缩进 40 pt，分隔线左缩进 52 pt。详情底部留 14 pt。

菜单栏场景必须声明 `.windowResizability(.contentSize)`；否则面板窗口只会随内容变高、不会变矮，收起后内容居中，上下留出透明空白。展开和收起即时切换，不做高度动画：带动画的高度变化会让面板和预览窗口都停在旧尺寸。唯一的动效是展开符号以 0.2 s `.smooth` 旋转 90°，并且只作用于该符号。

空状态横向留白 24 pt、纵向留白 40 pt。设置使用原生 grouped `Form`，不引入网页断点或移动端布局。

## Elevation & Depth

面板背景为 `.regularMaterial`，深浅色由系统处理。深度来自原生窗口、材质和 `Divider`，源码未设置自定义阴影、渐变或卡片堆叠。窗口轮廓与系统材质效果不应被转换成固定 CSS 阴影。

两张截图是承载真实 `ChargerPanel` 的原生调试预览，标题栏属于预览窗口；它不构成正式菜单栏面板的设计元素。

## Shapes

使用系统 SF Symbols、原生进度条与分隔线。外层圆角由窗口系统负责。按钮高亮使用 6 pt 连续圆角，左右各外扩 8 pt。端口整行通过矩形命中区域参与点击，不能将点击范围缩成右侧的小箭头。按钮和表单保留系统控件形态。

## Components

### Menu Label

菜单栏显示符号与最新总功率；过期或连接失败时显示 `— W`，尚未配置时显示应用名。失败符号使用 `wifi.slash`，常态使用 `bolt.horizontal.circle`。不得继续把旧值呈现为实时总输出。

### Connection Status

标题右侧组合状态文字与符号，覆盖 `Set up`、`Connecting`、`Offline`、`Stale`、`Connected`。摘要右下角显示最近一次成功读数的时间（等宽数字）。刷新失败后保留已有读数，由标题状态和错误说明表明它不是实时值。

### Port Row and History

整行是按钮，使用与页脚相同的菜单项式高亮，支持键盘与辅助功能。端口、设备名和状态在左，功率及展开符号在右。设备名限制为一行。状态区分无数据、未连接、已连接未充电与充电中，不从功率非零推导充电状态。

详情显示电压、电流、温度、协议、端口功率上限，以及当前运行期间最多一小时的曲线。曲线使用橙色、1.8 pt 线宽，纵轴从零开始，横轴隐藏并在下方显示首尾时间。不同采样分段分别绘制，不能把缺测时段连成连续历史。样本不足时显示 `Collecting samples…`。

### Actions and Empty States

页脚为一行 `.callout` 按钮：刷新单独居左，标签在“刷新”和“正在刷新”之间切换时不会推动其他按钮；设置与退出居右，退出使用次级文字色。按钮悬停时显示 7% 主色填充，按下立即加深到 14%；禁用时整体降至 45% 不透明度且无悬停反馈。刷新期间禁用刷新，未配置时也不可刷新。快捷键沿用 macOS：刷新为 Command-R，设置为 Command-Comma，退出为 Command-Q。首次配置、连接中和不可用状态分别给出设置入口、原生进度指示或重试入口。

### Settings

使用 grouped `Form`、`TextField`、`SecureField`、原生按钮与 `LabeledContent`。连接地址为安全输入；说明采用次级文字。不展示用户无法修改的监控参数。保存成功和失败反馈都使用主文本色，符号提供额外区分。默认操作为保存连接。

## Do's and Don'ts

### Do:

- **Do** 保持系统字体、原生材质、紧凑端口行与等宽数字。
- **Do** 同时检查深浅色，并确保重要状态文字有清晰对比。
- **Do** 区分真实零输出、缺失读数、旧读数和连接失败。
- **Do** 保留键盘操作、完整行命中区域与可理解的辅助功能标签。

### Don't:

- **Don't** 添加生成插画、装饰照片、自定义网页字体或卡片式仪表盘框架。
- **Don't** 把系统动态颜色、圆角和阴影冻结成未经验证的固定值。
- **Don't** 把调试预览标题栏作为正式菜单栏界面的一部分。
- **Don't** 用平滑连续线掩盖休眠或采样失败产生的时间缺口。

视觉证据为 `.impeccable/review/panel-light.png` 与 `.impeccable/review/detail-dark.png`：同一真实面板、实时 MCP 数据。它们支持浅色收起态和深色展开态的观察；正式菜单弹层的边缘与锚定、长时间休眠唤醒尚未动态验证。

## Localization

界面支持简体中文与英文，跟随 macOS 应用语言。状态、操作、错误提示和辅助功能标签均通过共享语言资源呈现；动态功率、计数和端口名通过格式占位符插入。文案变长时保留现有分组和换行，不缩小字体。设备名称优先使用对应语言的设备字段，未知协议名保留原文。

设置窗口由单一原生窗口控制器持有，内部继续使用 SwiftUI 表单。所有设置入口共享展示动作，显式激活应用并前置窗口；关闭后重用窗口，避免生成多个设置实例。

## Application Icon

用户后续明确要求生成应用图标。采用暖橙色圆角底座和象牙白立体闪电，源文件为 `Resources/AppIcon-v1.png`，通过 `AppIcon-v1.icns` 接入应用包。该图标是应用身份资产；其余界面仍保持原生材质与 SF Symbols，不扩展装饰插画。
