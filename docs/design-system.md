# MiLightBar 0.2 设计与交互

按用户指定的 ui-ux-pro-max 技能审阅；技能目录中的 scripts 是失效的路径占位文本，
无法运行 --design-system 搜索，因此直接按已读取的可访问性、原生导航和交互规范实施。
用户明确要求 macOS 原生，使用 SwiftUI/AppKit，而非技能通用示例中的 React Native。

- 主窗口：500×640 pt 起始尺寸，最小宽度 460 pt；只包含灯具电源、亮度、色温与固定一步微调。
- 导航：左上角原生 SettingsLink，系统应用菜单 Settings 与 ⌘,，独立 Settings scene。
- 设置：串口与波特率、遥控 ID/信道/无线配置/配对、诊断分层展示。
- 字体：系统字体，标题 26 pt，控件 .headline/.subheadline，数值等宽数字。
- 颜色：系统 window/background/primary/secondary 语义色；集中定义深浅两套琥珀强调色。
- 图标：原创 AppKit 矢量路径绘制挂灯与屏幕，生成标准 iconset/ICNS；控件统一 SF Symbols。
- 连续滑块：无 step；松手持久保存浮点目标，协议值 round 并限幅到 0…15。
- 无“应用”按钮及调节步长设置；四个微调按钮始终一个协议单位。
- 发送：逻辑命令起始间隔 ≥350 ms；同一滑块未发送目标合并，已发送事务不拆分；
  串口包间隔维持 25 ms，绝对设置的两阶段包保持连续事务，不与其他命令交错。
- 鼠标：拖动期间不提交新目标，松手后提交；键盘/辅助操作以 180 ms 消抖提交。
- 持久化：目标保存在当前用户的 MiLightBar preferences，不伪装成设备读数。
- 可访问性：原生 Slider/Button，保留键盘操作、辅助功能标签和系统焦点；用文字辅助状态，
  不仅凭颜色表达连接；无装饰性动画或自动移动。

主界面 .preferredColorScheme 预览开关只用于 --dark-preview / --light-preview，
不更改 macOS 系统外观。正常运行跟随系统。
