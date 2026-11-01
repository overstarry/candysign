# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS 原生菜单栏应用。

## Stack

用户已明确选择 Swift + SwiftUI；应用直接连接 MCP，首版无需独立服务。

## Users

Ming，通过菜单栏查看小电拼 2838 的充电状态。

## Product Purpose

随时查看五个端口的真实输出、连接状态和本次运行期间的曲线。

## Capabilities and Constraints

首版：菜单栏常驻、Keychain 配置、只读实时采集、手动与定时刷新、端口详情、内存曲线、设置、退出。设备控制、持久化历史和自动化不在首版范围。MCP 地址包含凭据，不写入源码、日志或截图。离线或过期数据不显示为实时零功率。Mac 休眠期间没有采样。

## Brand Commitments

参考用户提供的 CodexBar 截图：紧凑原生面板、系统字体、细分隔线、明确的数字层级、系统深浅色。使用系统 SF Symbols，不生成装饰素材。

## Evidence on Hand

真实 MCP 已验证设备为 CP-02S / CoCan Mirror，最大总功率 160 W，A、C1、C2、C3、C4 五端口。历史接口样本未提供时间戳，首版只展示应用自己采集的时间序列。

## Localization

用户要求支持中文。已实现简体中文与英文，跟随系统应用语言，英文回退。文案位于独立语言资源，保留原生视觉风格。
