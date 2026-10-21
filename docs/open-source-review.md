# 开源前代码检查

日期：2026-10-21。范围：lightbar-macos 当前源码、测试、构建/安装脚本、待发布文件；不是完整历史或硬件固件安全审计。

## 本轮发现与修复

- 首次启动可能向自动选中的其他串口发送 AT?：改为仅自动连接已识别成功且保存的端口，首次连接需手动确认。设备路径重用仍需使用者确认，不能视为设备认证。
- 写无线配置前只要求非空响应：改为要求地址、频率、CRC 和速率四类参数完整可识别，再备份并写入；纯 OK 和缺失字段均拒绝。
- 串口路径前缀校验不充分：拒绝子路径和 NUL，open 使用 O_NOFOLLOW，写入前 fstat 要求字符设备。
- 公共发送方法未验证重复次数，负数可能触发范围崩溃：在进入发送循环前限制 1…30。
- 测试日志和实机记录包含本机路径及配对信息：公开源码快照排除这些文件；README 使用通用路径，不发布实际配对 ID。本公开仓库从源码快照独立初始化，不包含原工作仓库历史。

## 检查结论与发布待办

静态检查未发现 Sources 中的网络回传、shell/进程执行、硬编码登录密码、访问令牌或私钥。构建和安装依赖固定的系统工具，不下载或安装依赖。这个结论仅针对检查范围，不代表形式化安全证明。

上游参考：https://github.com/lamperez/xiaomi-lightbar-nrf24 ，2026-10-21 仓库页标注 GPL-3.0（COPYING）。本项目采用 GPL-3.0-only，完整许可证随源码分发。协议参考及公开测试向量的来源保留在 THIRD_PARTY_NOTICES.md；没有打包上游 Python 模块、第三方运行库或厂商 PDF。

无线兼容性、闪烁和偶尔关灯问题仍未解决；详见 SECURITY.md。没有把本次软件回归写成硬件互通验证。

## Validation

2026-10-21: XCTest 18 cases, 17 passed, 1 hardware query skipped, 0 failures. Includes serial argument rejection, incomplete module response rejection, packet/CRC vectors, scheduling, AppKit window lifecycle and light/dark rendering. Shell syntax checks passed. No hardware commands or application reinstall in this review. Raw test output stays in ignored local evidence.
