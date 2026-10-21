# 米家挂灯 · macOS 原生控制器

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

SwiftUI + AppKit，macOS 14+，无第三方运行依赖。
通过 DevEBox nRF24L01 无线串口模块控制 MJGJD01YL，默认 115200 / 8N1 / 无流控。

## 安装与使用

已安装时，打开 `/Applications/MiLightBar.app`。

1. 点击主窗口左上角齿轮，或按 `⌘,` 打开原生设置。
2. 在“连接”选择模块端口（例如 `/dev/cu.usbserial-YOUR_DEVICE`），点击“连接”。
   应用只读识别已有无线参数；匹配后即可控制，无需重复配对或写参数。
3. 回到主窗口：电源按钮切换开关；连续拖动亮度/色温滑块，松开后自动保存并发送。
4. 四个微调按钮每次固定一个协议单位，无调节步长设置。
5. 首次使用需手动确认并连接串口；之后默认启动时自动连接上次识别成功的设备，并只读查询模块参数；可在设置中关闭“启动时连接上次设备”。上次串口缺失时不会自动连接其他端口。
6. App 仅驻留顶部菜单栏，不显示 Dock 图标（0.3.1 起）；点击菜单栏灯泡小图标打开控制窗口；点击窗口 × 仅隐藏窗口，串口保持连接。右键菜单栏图标选择“退出米家挂灯”，或按 `⌘Q` 才会退出。

自动连接不会发送电源、亮度、色温或配对指令，也不会恢复滑块目标到灯上。隐藏后再打开窗口不会重复执行启动连接。

滑块无分档卡点，保存浮点目标，实际发送自动 round 到灯支持的 0…15。
界面显示百分比/近似色温目标，不代表设备读数；灯具没有状态回传。
主界面没有串口配置、日志、“应用”按钮和步长控件。

## 自动发送策略

- 拖动中仅更新显示，不提交新目标；松手后保存并排队发送。
- 键盘或辅助功能调节以 180 ms 消抖提交。
- 逻辑指令开始时间至少相隔 **350 ms**，串口包间保持至少 **25 ms**。
- 正在发送时仍可拖动；同一滑块未发送的旧目标由最新目标替换。
- 已开始的两阶段绝对设置作为完整事务发送，不拆开、不与其他操作交错。
- 包默认重复 20 次，因此某些完整绝对设置约需 1 秒；350 ms 是下限，不是固定完成延迟。
- 重复协议档位不会无意义重发；微调按钮的逐次点击保持顺序。
- 断开/取消会停止后续发送，已发送的无线包无法撤回。

## 首次无线配置与配对

已有成功配置和遥控器 ID 时不必重做。
首次使用在设置中保留/填写 6 位十六进制 ID，选择信道 6（2406 MHz）并执行“无线配置…”。
需要改变参数时，应用先保存原参数到
`~/Library/Application Support/MiLightBar/ModuleBackups/`，再设置 2 Mbps、16 位硬件 CRC、
TX 地址 `55:55:55:55:55` 与选定信道；原串口波特率和 RX 地址不变。
配置会保存到模块。备份是参数文本记录，不是完整固件镜像。

配对时给灯断电再上电，20 秒内在设置中发送配对命令；灯闪烁才代表成功。
新 ID 会替换原遥控器，可用原遥控器重新配对撤销。每台安装独立生成并保存 ID，不要公开实际已配对 ID 或完整控制包。

## 源码构建和安装

需要已安装 Xcode 或兼容 Command Line Tools，Swift 6+。

```sh
git clone https://github.com/zlinwei/lightbar-macos.git
cd lightbar-macos
./scripts/build-app.sh
./scripts/install-app.sh
open /Applications/MiLightBar.app
```

本机 xcode-select 当前选中 Command Line Tools；构建/测试可在命令前设置：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

构建脚本默认 Release，可用 `BUILD_ROOT`、`MODULE_CACHE` 和 `BUILD_MODE` 覆盖。
图标由 `scripts/generate-icon.swift` 的原创矢量路径生成，输出 16…1024 像素 iconset 和 ICNS，
自动写入 bundle 并 ad-hoc 签名。无需图形库或下载素材。
安装脚本只操作本应用；同名目标如非本 bundle ID 会停止，旧本应用会备份到
`~/Library/Application Support/MiLightBar/AppBackups/` 再替换。

源码可用 Xcode 打开 `Package.swift`。生成的 `.app` 是本机架构的 ad-hoc 签名，
尚未做 Developer ID 签名和公证，不声明可在任意机器直接分发。
本机串口已可识别，不安装资料中附带的旧 CH340 驱动，不刷模块固件。

## 验证

```sh
# XCTest 需要完整 Xcode；本机需显式选择工具链。
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test

# 真实串口检查：先在应用设置中断开，避免独占冲突。
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
LIGHTBAR_TEST_SERIAL=/dev/cu.usbserial-YOUR_DEVICE \
LIGHTBAR_RENDER_PREVIEWS=/tmp/lightbar-previews xcrun swift test
```

0.2 版：15 项离线测试（含深浅色渲染）和 1 项真实串口检查，共 **16 项通过**，零失败、零跳过。
覆盖捕获包/CRC、非法值拒绝、命令、模块参数解析、连续值 round、目标合并、
拖动抑制、固定一步微调顺序及最小发送间隔；直接验证应用回调在拖动中零发送、松手提交、快速目标合并与键盘自动提交。

0.1 实机验证中，用户已确认配对闪烁、电源切换、亮度 2→12 和暖白→冷白均生效；
模块为固件 3.00（2019-04-08）。0.2 沿用已验证的无线协议，新增自动发送与界面行为。
具体安装与实机原始记录保留在维护者本地，不随源码发布。

0.3 新增真实 AppKit 窗口关闭隐藏、同窗口恢复、Dock 重开及关闭后不退出的生命周期检查；完整测试共 17 项。原始验证记录保留在维护者本地。

后续用户报告重复 3 次时微调也会闪烁，且偶尔持续关灯，原因尚未定位。之前的实机成功记录不代表所有控制操作稳定；0.3 未修改无线包或发送时序，也未修复或重新验证该故障。

默认测试会跳过未启用的实机/离屏渲染检查；上面第二条命令启用完整 18 项。

## 项目结构与设计

- `Sources/LightBarCore/`：协议包、CRC、串口 actor、模块参数解析和待发目标队列。
- `Sources/MiLightBar/`：原生主窗口、Settings、状态和发送调度。
- `Tests/LightBarCoreTests/`：协议、队列和可选真实串口测试。
- `scripts/`：构建、图标生成及带备份安装脚本。
- [设计规则](docs/design-system.md)：ui-ux-pro-max 应用于 macOS 的布局、颜色、导航和交互。

正常运行跟随系统深浅色；开发时可用 `--demo --dark-preview` / `--demo --light-preview`
只预览本应用外观，不改系统主题。演示不连接硬件，不作为实机测试证据。

协议布局为 sync8 + ID3 + FF1 + counter1 + command2 + CRC2；多字节字段为大端。
CRC16：poly 0x1021、init 0xFFFE、无反射、xorout 0。
模块自带长度字段及固定 32 字节无线封装，本机实测仍能控制灯；尚未抓取空中帧，
其他固件/个体、信道 43/68 和长时间稳定性未覆盖。

按用户提供的 DevEBox 1904M/1908M 手册和以下公开协议事实独立实现：
[lamperez/xiaomi-lightbar-nrf24](https://github.com/lamperez/xiaomi-lightbar-nrf24)、
[baseband](https://github.com/lamperez/xiaomi-lightbar-nrf24/blob/main/xiaomi_lightbar/baseband.py)、
[radio](https://github.com/lamperez/xiaomi-lightbar-nrf24/blob/main/xiaomi_lightbar/radio.py)。

## 许可证与来源

本项目采用 **GNU General Public License v3.0 only**（`GPL-3.0-only`），完整条款见 [LICENSE](LICENSE)。分发修改版或二进制时请遵守该许可证的通知及对应源码要求。

协议资料、公开测试向量和参考项目的来源见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。本项目与小米、Yeelight、DevEBox 无隶属或背书关系。

风险审查及修复见 [开源检查记录](docs/open-source-review.md)，运行、日志和已知稳定性边界见 [SECURITY.md](SECURITY.md)。
