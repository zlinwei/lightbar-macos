// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import Foundation
import LightBarCore
import Observation

struct LogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let kind: String
    let message: String
}

@MainActor @Observable
final class AppModel {
    var ports: [String] = []
    var selectedPort = ""
    var remoteID: String { didSet { if !demo { UserDefaults.standard.set(remoteID,forKey:"MiLightBar.remoteID") } } }
    var channel = 6 { didSet { configured = false; if !demo { UserDefaults.standard.set(channel,forKey:"MiLightBar.channel") } } }
    var repetitions = 20
    var brightness = 8.0
    var temperature = 8.0
    var brightnessEditing = false
    var temperatureEditing = false
    var isSending = false
    var pendingCount = 0
    var controlActive = false
    var canControl: Bool { connected && configured && !busy }
    var autoConnect: Bool { didSet { if !demo { UserDefaults.standard.set(autoConnect,forKey:"MiLightBar.autoConnect") } } }
    private var queue = ControlQueue()
    private var sender: Task<Void,Never>?
    private var brightnessDebounce: Task<Void,Never>?
    private var temperatureDebounce: Task<Void,Never>?
    private var lastSendStart: ContinuousClock.Instant?
    private var inFlight: ControlIntent?
    private var lastSent: [AbsoluteControl:Int] = [:]
    var connected = false
    var configured = false
    var busy = false
    var status = "选择串口，连接后查询模块"
    var failure: String?
    var entries: [LogEntry] = []
    var pairingPresented = false
    var configurationPresented = false
    var moduleSnapshot = ""
    let demo: Bool
    private let serial = SerialPort()
    private var counter: UInt8
    private var startupAttempted = false
    private var operation: Task<Void, Never>?

    init(demo: Bool = false) {
        self.demo = demo
        autoConnect = !demo && (UserDefaults.standard.object(forKey:"MiLightBar.autoConnect") as? Bool ?? true)
        func target(_ key: String) -> Double {
            guard let value = UserDefaults.standard.object(forKey:key) as? Double, value.isFinite else { return 8 }
            return min(15,max(0,value))
        }
        if !demo {
            brightness = target("MiLightBar.brightnessTarget")
            temperature = target("MiLightBar.temperatureTarget")
        }
        remoteID = demo ? "A1B2C3" : UserDefaults.standard.string(forKey:"MiLightBar.remoteID") ?? String(format:"%06X",UInt32.random(in:1...0xFFFFFF))
        counter = UInt8(truncatingIfNeeded: UserDefaults.standard.integer(forKey:"MiLightBar.counter"))
        if !demo { UserDefaults.standard.set(remoteID,forKey:"MiLightBar.remoteID") }
        let savedChannel = UserDefaults.standard.integer(forKey:"MiLightBar.channel")
        if [6,43,68].contains(savedChannel) { channel = savedChannel }
        refreshPorts()
        if demo { status = "演示模式 · 不连接硬件，不发送无线数据"; log("演示",status) }
    }
    func refreshPorts() {
        ports = SerialPort.ports()
        if !ports.contains(selectedPort) {
            let saved = UserDefaults.standard.string(forKey:"MiLightBar.port") ?? ""
            selectedPort = ports.contains(saved) ? saved : ports.first(where:{$0.contains("usbserial")}) ?? ports.first ?? ""
        }
    }
    func connect() {
        guard !selectedPort.isEmpty else { failure = "没有可用的 USB 串口。"; return }
        run {
            if !self.demo { try await self.serial.connect(path:self.selectedPort) }
            self.connected = true
            self.status = self.demo ? "演示连接 · 不发送" : "串口已连接 · 115200 8N1"
            self.log("连接",self.status + " · " + self.selectedPort)
        }
    }
    func disconnect() {
        cancelControls(); lastSent.removeAll()
        operation?.cancel()
        // Cancellation is checked within the actor's polling/send loops.
        Task {
            await serial.disconnect()
            connected = false; configured = false; status = "串口已断开"
            log("连接",status)
        }
    }
    func query() {
        run {
            guard self.connected else { throw ModuleError.notConnected }
            self.moduleSnapshot = ""
            for command in [ModuleProtocol.query, ModuleProtocol.version] {
                let reply = try await self.exchange(command)
                self.moduleSnapshot += self.text(reply) + "\n"
                if command == ModuleProtocol.query { self.configured = ModuleStatus(reply:reply).matchesLightBar(channel:self.channel) }
            }
            self.status = self.configured ? "模块配置已匹配 · 可以直接控制" : self.moduleSnapshot.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "未收到模块响应，请检查端口和波特率" : "模块参数已读取 · 请应用无线配置"
        }
    }
    func configure() {
        run {
            guard self.connected else { throw ModuleError.notConnected }
            self.configured = false
            let previous = try await self.exchange(ModuleProtocol.query)
            let previousStatus = ModuleStatus(reply:previous)
            guard previousStatus.isRecognized else { throw ModuleError.unexpectedReply }
            if previousStatus.matchesLightBar(channel:self.channel) {
                self.configured = true; self.status = "无线参数已匹配，无需重复写入"; return
            }
            let previousText = self.text(previous)
            self.moduleSnapshot = previousText
            if !self.demo { try self.saveSnapshot(previousText) }
            for command in try ModuleProtocol.configure(channel:self.channel) {
                let reply = try await self.exchange(command)
                let text = self.text(reply)
                guard !reply.isEmpty, text.contains("成功") || text.localizedCaseInsensitiveContains("OK") else { throw ModuleError.unexpectedReply }
            }
            let final = try await self.exchange(ModuleProtocol.query)
            guard ModuleStatus(reply:final).matchesLightBar(channel:self.channel) else { throw ModuleError.unexpectedReply }
            self.configured = true
            self.status = "无线参数已写入 · 可以尝试配对与控制"
            self.log("提示","模块配置保存在设备中；灯是否响应仍需实际观察。")
        }
    }
    func send(_ command: LightCommand) { enqueue(.command(command)) }
    func pair() { enqueue(.command(.reset)) }
    func editing(_ control: AbsoluteControl, changed editing: Bool) {
        log("交互", "\(control == .brightness ? "亮度" : "色温")拖动\(editing ? "开始" : "结束")")
        switch control {
        case .brightness: brightnessEditing = editing; brightnessDebounce?.cancel()
        case .temperature: temperatureEditing = editing; temperatureDebounce?.cancel()
        }
        if editing { queue.remove(control); pendingCount = queue.count }
        else { commit(control) }
    }
    func valueChanged(_ control: AbsoluteControl) {
        guard !(control == .brightness ? brightnessEditing : temperatureEditing) else { return }
        let task = Task { [weak self] in
            do { try await Task.sleep(for:SendTiming.keyboardDebounce) }
            catch { return }
            self?.commit(control)
        }
        switch control {
        case .brightness: brightnessDebounce?.cancel(); brightnessDebounce = task
        case .temperature: temperatureDebounce?.cancel(); temperatureDebounce = task
        }
    }
    func startIfRequested() {
        guard !startupAttempted else { return }
        startupAttempted = true
        guard autoConnect, !demo, !connected, !busy else { return }
        guard let saved = UserDefaults.standard.string(forKey:"MiLightBar.port"), !saved.isEmpty else {
            status = "首次使用请在设置中选择并连接串口"
            return
        }
        guard ports.contains(saved) else {
            status = "上次的串口未接入，请在设置中连接"
            log("连接",status + " · " + saved)
            return
        }
        selectedPort = saved
        connectAndQuery()
    }
    func connectAndQuery() {
        guard !selectedPort.isEmpty else { failure = "没有可用的 USB 串口。"; return }
        run {
            if !self.demo { try await self.serial.connect(path:self.selectedPort) }
            self.connected = true
            let info = try await self.exchange(ModuleProtocol.query)
            let module = ModuleStatus(reply:info)
            if !self.demo && module.isRecognized { UserDefaults.standard.set(self.selectedPort,forKey:"MiLightBar.port") }
            self.moduleSnapshot = self.text(info)
            self.configured = self.demo || module.matchesLightBar(channel:self.channel)
            self.status = self.configured ? "已连接，可以控制" : "请在设置中完成无线配置"
        }
    }
    private func commit(_ control: AbsoluteControl) {
        let value = control == .brightness ? brightness : temperature
        let level = ControlIntent.roundedLevel(value)
        if !demo {
            UserDefaults.standard.set(value,forKey:control == .brightness ? "MiLightBar.brightnessTarget" : "MiLightBar.temperatureTarget")
        }
        if (inFlight?.absolute == control && inFlight?.level == level) || lastSent[control] == level {
            queue.remove(control); pendingCount = queue.count; return
        }
        enqueue(control == .brightness ? .brightness(level) : .temperature(level))
    }
    private func enqueue(_ intent: ControlIntent) {
        guard canControl else { status = "请先在设置中连接挂灯"; return }
        queue.enqueue(intent); pendingCount = queue.count
        startSender()
    }
    private func cancelControls() {
        brightnessDebounce?.cancel(); temperatureDebounce?.cancel()
        sender?.cancel(); queue.removeAll(); pendingCount = 0
    }
    private func startSender() {
        guard sender == nil, !busy, connected, configured, !queue.isEmpty else { return }
        controlActive = true
        sender = Task {
            defer { sender = nil; inFlight = nil; isSending = false; controlActive = false }
            do {
                while !Task.isCancelled {
                    let delay = SendTiming.remaining(since:lastSendStart,now:ContinuousClock.now)
                    if delay > .zero { try await Task.sleep(for:delay) }
                    try Task.checkCancellation()
                    var editing: Set<AbsoluteControl> = []
                    if brightnessEditing { editing.insert(.brightness) }
                    if temperatureEditing { editing.insert(.temperature) }
                    guard let intent = queue.next(excluding:editing) else { break }
                    pendingCount = queue.count
                    inFlight = intent
                    if let key = intent.affected { lastSent.removeValue(forKey:key) }
                    if case .command(.reset) = intent { lastSent.removeAll() }
                    isSending = true; lastSendStart = ContinuousClock.now
                    try await perform(intent)
                    isSending = false; inFlight = nil
                }
            } catch is CancellationError {
                status = "发送已停止"
            } catch {
                failure = error.localizedDescription; status = "发送失败，请检查设置"
                log("错误",error.localizedDescription)
                queue.removeAll(); pendingCount = 0; configured = false
                await serial.disconnect(); connected = false
            }
        }
    }
    func clearLog() { entries.removeAll() }
    func exportLog() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "MiLightBar-diagnostics.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try entries.map { "\($0.date.formatted()) [\($0.kind)] \($0.message)" }.joined(separator:"\n").write(to:url,atomically:true,encoding:.utf8) }
        catch { failure = error.localizedDescription }
    }
    private func perform(_ intent: ControlIntent) async throws {
        let id = try LightBarPacket.remoteID(remoteID)
        var packets: [Data] = []
        for code in try intent.codes() {
            let packet = try LightBarPacket.make(remoteID:id,code:code,counter:counter)
            counter &+= 1
            if !demo { UserDefaults.standard.set(Int(counter),forKey:"MiLightBar.counter") }
            packets.append(packet); log("灯包",packet.hex)
        }
        if !demo {
            for reply in try await serial.transmit(packets:packets,repetitions:repetitions) {
                log("RX",text(reply)+" | "+reply.hex)
            }
        }
        switch intent {
        case .brightness(let value): lastSent[.brightness] = value
        case .temperature(let value): lastSent[.temperature] = value
        case .command(.brighter), .command(.dimmer): lastSent.removeValue(forKey:.brightness)
        case .command(.warmer), .command(.cooler): lastSent.removeValue(forKey:.temperature)
        case .command(.reset): lastSent.removeAll()
        default: break
        }
        status = demo ? "演示：\(intent.label)" : "已发送 · \(intent.label)"
        log("发送",intent.label+"，每包重复 \(repetitions) 次；灯具无状态回传。")
    }
    private func exchange(_ command: Data) async throws -> Data {
        log("TX",String(data:command,encoding:.utf8) ?? command.hex)
        let reply: Data
        if demo { reply = Data("OK\n目标地址：0x55,0x55,0x55,0x55,0x55\n通信频率：2.406GHz\n校验方式:16位CRC校验\n空中传输速率：2Mbps\n".utf8) }
        else { reply = try await serial.exchange(command,waitMilliseconds:500) }
        log("RX",reply.isEmpty ? "（无响应）" : text(reply)+" | "+reply.hex)
        return reply
    }
    private func run(_ body: @escaping @MainActor () async throws -> Void) {
        guard !busy, sender == nil else { return }
        busy = true; failure = nil
        operation = Task {
            defer { busy = false; operation = nil; startSender() }
            do { try await body() }
            catch is CancellationError { status = "操作已取消；部分包可能已经发送"; log("取消",status) }
            catch {
                failure = error.localizedDescription; status = "操作失败，请查看诊断"
                configured = false
                log("错误",error.localizedDescription)
                await serial.disconnect(); connected = false
            }
        }
    }
    private func text(_ data: Data) -> String { ModuleProtocol.replyText(data) }
    private func saveSnapshot(_ text: String) throws {
        let directory = try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("MiLightBar/ModuleBackups",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let path = directory.appendingPathComponent("before-\(UUID().uuidString).txt")
        try ("\(Date().formatted())\n\(selectedPort) 115200 8N1\n"+text).write(to:path,atomically:true,encoding:.utf8)
        log("备份",path.path)
    }
    private func log(_ kind: String, _ message: String) {
        entries.append(LogEntry(kind:kind,message:message))
        if entries.count > 300 { entries.removeFirst(entries.count-300) }
    }
}
