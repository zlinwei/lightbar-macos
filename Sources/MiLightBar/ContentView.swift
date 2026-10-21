// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import LightBarCore

struct ContentView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing:28) {
            header
            lamp
            VStack(spacing:26) {
                control(title:"亮度",symbol:"sun.max",value:$model.brightness,
                        readout:"\(Int((model.brightness / 15 * 100).rounded()))%",low:"柔和",high:"明亮",kind:.brightness)
                Divider()
                control(title:"色温",symbol:"thermometer.sun",value:$model.temperature,
                        readout:"\(Int(((2700 + model.temperature / 15 * 3800) / 100).rounded()) * 100) K",low:"暖白",high:"冷白",kind:.temperature)
            }
            .padding(24)
            .background(.background,in:RoundedRectangle(cornerRadius:20))
            .overlay { RoundedRectangle(cornerRadius:20).stroke(.quaternary,lineWidth:1) }
            VStack(spacing:6) {
                HStack(spacing:7) {
                    if model.isSending { ProgressView().controlSize(.mini) }
                    Text(model.connected && model.configured ? model.pendingCount > 0 ? "正在发送，已保留最新目标" : "松开滑块后自动保存并发送" : "请在设置中连接挂灯")
                }
                Text("灯具无状态回传，滑块显示目标值").font(.caption).foregroundStyle(.secondary)
            }.font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength:0)
        }
        .padding(28)
        .frame(minWidth:460,idealWidth:500,minHeight:620)
        .background(Color(nsColor:.windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement:.navigation) {
                SettingsLink { Label("设置",systemImage:"gearshape") }.help("设置（⌘,）")
            }
        }
        .alert("操作未完成",isPresented:Binding(get:{model.failure != nil},set:{if !$0 { model.failure = nil }})) {
            Button("好",role:.cancel) { model.failure = nil }
        } message: { Text(model.failure ?? "") }
        .onChange(of:model.brightness) { _,_ in model.valueChanged(.brightness) }
        .onChange(of:model.temperature) { _,_ in model.valueChanged(.temperature) }
        .task { model.startIfRequested() }
    }
    private var header: some View {
        HStack(alignment:.center) {
            VStack(alignment:.leading,spacing:7) {
                Text("桌面，刚刚好").font(.system(size:26,weight:.semibold,design:.rounded))
                Label(model.demo ? "演示模式" : model.connected && model.configured ? "已连接" : "未连接",systemImage:model.connected && model.configured ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.send(.toggle) } label: {
                Image(systemName:"power").font(.system(size:23,weight:.medium)).foregroundStyle(LampTheme.onAccent).frame(width:54,height:54)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.circle).tint(LampTheme.accent)
            .accessibilityLabel("切换灯的电源").help("切换电源（⌘P）")
            .keyboardShortcut("p",modifiers:.command)
            .disabled(!model.canControl || model.controlActive)
        }
    }
    private var lamp: some View {
        ZStack {
            RoundedRectangle(cornerRadius:20).fill(.background)
            Ellipse().fill(LampTheme.accent.opacity(0.12)).frame(width:290,height:40).blur(radius:16).offset(y:38)
            VStack(spacing:0) {
                Capsule().fill(.primary.opacity(0.75)).frame(width:290,height:9)
                Capsule().fill(LampTheme.accent.opacity(0.85)).frame(width:270,height:2)
                RoundedRectangle(cornerRadius:5).stroke(.secondary.opacity(0.2),lineWidth:1).frame(width:246,height:62)
            }
        }.frame(height:118).accessibilityHidden(true)
    }
    private func control(title:String,symbol:String,value:Binding<Double>,readout:String,low:String,high:String,kind:AbsoluteControl) -> some View {
        VStack(spacing:12) {
            HStack {
                Label(title,systemImage:symbol).font(.headline)
                Spacer()
                Text(readout).font(.system(.title3,design:.rounded).weight(.medium)).monospacedDigit()
            }
            Slider(value:value,in:0...15,onEditingChanged:{ model.editing(kind,changed:$0) })
                .controlSize(.large).accessibilityLabel(title+"目标")
                .accessibilityValue(readout)
            HStack {
                Text(low).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if kind == .brightness {
                    microButton("暗一点",icon:"minus",command:.dimmer(1))
                    microButton("亮一点",icon:"plus",command:.brighter(1))
                } else {
                    microButton("暖一点",icon:"sun.min",command:.warmer(1))
                    microButton("冷一点",icon:"snowflake",command:.cooler(1))
                }
                Spacer()
                Text(high).font(.caption).foregroundStyle(.secondary)
            }
        }.disabled(!model.canControl)
    }
    private func microButton(_ title:String,icon:String,command:LightCommand) -> some View {
        Button { model.send(command) } label: { Image(systemName:icon).frame(width:32,height:24) }
            .buttonStyle(.bordered).accessibilityLabel(title).help(title)
    }
}
