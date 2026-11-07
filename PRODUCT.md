# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS、Windows、Linux 桌面应用；macOS 使用菜单栏浮层，Windows/Linux 使用普通窗口。

## Stack

Rust + GPUI Kit 0.9.0。旧 Swift 实现已移除，当前为仅含演示数据的桌面交互原型，尚未接入真实 MCP。

## Users

Ming，通过菜单栏查看小电拼 2838 的充电状态。

## Product Purpose

随时查看五个端口的真实输出、连接状态和本次运行期间的曲线。

## Capabilities and Constraints

当前：托盘入口、五端口演示读数、合成曲线、手动切换样本、外观与语言设置、模拟过期/离线状态。设置仅影响本次运行。

待实现：真实 MCP 只读采集、安全凭据存储、定时刷新、真实历史分段、睡眠恢复和安装包。设备控制、持久化历史和自动化不在当前范围。未来接入时 MCP 地址包含的凭据不得写入源码、日志或截图；离线或过期数据不得冒充实时零功率。

## Brand Commitments

参考用户提供的 CodexBar 截图：紧凑原生面板、系统字体、细分隔线、明确的数字层级、系统深浅色。使用系统 SF Symbols，不生成装饰素材。

## Evidence on Hand

旧版曾通过真实 MCP 验证设备为 CP-02S / CoCan Mirror，最大总功率 160 W，A、C1、C2、C3、C4 五端口。历史接口样本未提供时间戳，未来真实曲线应使用应用自己采集的时间序列。此历史验证不代表当前 Rust 原型已接入设备。

## Localization

用户要求支持中文。原型已实现简体中文与英文，默认跟随启动时的系统语言，非中文系统回退英文，也可手动切换。文案位于 Rust 源码，保留原生视觉风格。
