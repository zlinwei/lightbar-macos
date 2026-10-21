// SPDX-License-Identifier: GPL-3.0-only
import LightBarCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        TabView {
            connection.tabItem { Label("连接",systemImage:"cable.connector") }
            diagnostics.tabItem { Label("诊断",systemImage:"waveform.path.ecg") }
        }
        .frame(width:560,height:530)
        .padding(12)
        .alert("操作未完成",isPresented:Binding(get:{model.failure != nil},set:{if !$0 { model.failure = nil }})) {
            Button("好",role:.cancel) { model.failure = nil }
        } message: { Text(model.failure ?? "") }
        .confirmationDialog("应用无线配置？",isPresented:$model.configurationPresented,titleVisibility:.visible) {
            Button("备份并应用") { model.configure() }
        } message: { Text("将查询并比对现有参数；需要变更时先备份，再设置 2 Mbps、CRC16、地址 55:55:55:55:55 和信道 \(model.channel)。波特率保持 115200。") }
        .confirmationDialog("配对挂灯？",isPresented:$model.pairingPresented,titleVisibility:.visible) {
            Button("灯已重新上电，发送配对命令") { model.pair() }
        } message: { Text("给灯断电再上电，20 秒内发送。灯闪烁才表示成功；将替换原遥控器。") }
    }
    private var connection: some View {
        Form {
            Section("串口") {
                Picker("设备",selection:$model.selectedPort) {
                    if model.ports.isEmpty { Text("未发现 USB 串口").tag("") }
                    ForEach(model.ports,id:\.self) { Text($0).tag($0) }
                }.disabled(model.connected || model.busy || model.controlActive)
                HStack {
                    Text("115200 · 8N1 · 无流控").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("刷新") { model.refreshPorts() }.disabled(model.connected || model.busy)
                    Button(model.connected ? "断开" : "连接") { model.connected ? model.disconnect() : model.connectAndQuery() }
                        .disabled(!model.connected && (model.busy || model.selectedPort.isEmpty))
                }
                Toggle("启动时连接上次设备",isOn:$model.autoConnect)
            }
            Section("挂灯") {
                TextField("遥控器 ID",text:$model.remoteID).help("6 位十六进制，保留已经配对的 ID")
                Picker("无线信道",selection:$model.channel) {
                    Text("6 · 2406 MHz").tag(6); Text("43 · 2443 MHz").tag(43); Text("68 · 2468 MHz").tag(68)
                }
                Stepper("发包重复 \(model.repetitions) 次",value:$model.repetitions,in:1...30)
                HStack {
                    Button("查询参数") { model.query() }
                    Button("无线配置…") { model.configurationPresented = true }
                    Button("配对…") { model.pairingPresented = true }.disabled(!model.configured)
                }.disabled(!model.connected)
            }.disabled(model.busy || model.controlActive)
            Text(model.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }.formStyle(.grouped)
    }
    private var diagnostics: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text("通信记录").font(.headline)
                Spacer()
                Button("导出…") { model.exportLog() }
                Button("清空") { model.clearLog() }
            }
            ScrollView {
                LazyVStack(alignment:.leading,spacing:8) {
                    ForEach(model.entries) { entry in
                        Text("\(entry.date.formatted(date:.omitted,time:.standard)) [\(entry.kind)] \(entry.message)")
                            .font(.system(size:11,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                    }
                }
            }.padding(12).background(.background,in:RoundedRectangle(cornerRadius:10))
            Text("滑块松手后提交；最小命令起始间隔 350 ms，快速调整仅保留最新目标。灯具不回传状态。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16)
    }
}
