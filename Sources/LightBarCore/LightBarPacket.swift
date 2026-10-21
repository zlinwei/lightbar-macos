// SPDX-License-Identifier: GPL-3.0-only
import Foundation

public enum PacketError: Error, LocalizedError {
    case invalidRemoteID, invalidStep, invalidLevel
    public var errorDescription: String? {
        switch self {
        case .invalidRemoteID: "遥控器 ID 必须为 6 位十六进制数。"
        case .invalidStep: "调节步长必须在 1…15 之间。"
        case .invalidLevel: "绝对档位必须在 0…15 之间。"
        }
    }
}

public enum LightCommand: Sendable {
    case toggle, reset, brighter(Int), dimmer(Int), cooler(Int), warmer(Int)
    public func code() throws -> UInt16 {
        switch self {
        case .toggle: return 0x0100
        case .reset: return 0x0600
        case .brighter(let n): return try stepped(0x0400, n)
        case .dimmer(let n): return try stepped(0x0500, n, decrease: true)
        case .cooler(let n): return try stepped(0x0200, n)
        case .warmer(let n): return try stepped(0x0300, n, decrease: true)
        }
    }
    private func stepped(_ base: Int, _ step: Int, decrease: Bool = false) throws -> UInt16 {
        guard (1...15).contains(step) else { throw PacketError.invalidStep }
        return UInt16(decrease ? base - step : base + step)
    }
}

public enum LightBarPacket {
    public static func remoteID(_ text: String) throws -> UInt32 {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count == 6, clean.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              let id = UInt32(clean, radix: 16) else { throw PacketError.invalidRemoteID }
        return id
    }
    public static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFE
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 { crc = (crc & 0x8000 != 0) ? (crc &<< 1) ^ 0x1021 : crc &<< 1 }
        }
        return crc
    }
    /// Observed layout: sync8 + remoteID3 + FF + counter1 + command2 + CRC2.
    public static func make(remoteID: UInt32, code: UInt16, counter: UInt8) throws -> Data {
        guard remoteID <= 0xFFFFFF else { throw PacketError.invalidRemoteID }
        var bytes: [UInt8] = [0x53,0x39,0x14,0xDD,0x1C,0x49,0x34,0x12,
            UInt8(truncatingIfNeeded: remoteID >> 16),UInt8(truncatingIfNeeded: remoteID >> 8),UInt8(truncatingIfNeeded: remoteID),
            0xFF,counter,UInt8(code >> 8),UInt8(truncatingIfNeeded: code)]
        let crc = crc16(bytes); bytes += [UInt8(crc >> 8), UInt8(truncatingIfNeeded: crc)]
        return Data(bytes)
    }
    public static func absoluteBrightness(_ value: Int) throws -> [UInt16] {
        guard (0...15).contains(value) else { throw PacketError.invalidLevel }
        return [0x04F0, 0x0400 + UInt16(value)]
    }
    public static func absoluteTemperature(_ value: Int) throws -> [UInt16] {
        guard (0...15).contains(value) else { throw PacketError.invalidLevel }
        return [0x02F0, 0x0200 + UInt16(value)]
    }
}

public enum ModuleProtocol {
    public static let query = Data("AT?".utf8)
    public static let version = Data("AT+VER".utf8)
    public static func configure(channel: Int) throws -> [Data] {
        guard [6,43,68].contains(channel) else { throw ModuleError.invalidChannel }
        return ["AT+RATE=3", "AT+CRC=16", "AT+TXA=0x55,0x55,0x55,0x55,0x55", String(format:"AT+FREQ=2.%03dG",400+channel)].map { Data($0.utf8) }
    }
}
public enum ModuleError: Error, LocalizedError {
    case invalidChannel, notConnected, busy, system(String), writeTimeout, unexpectedReply, cancelled
    public var errorDescription: String? {
        switch self {
        case .invalidChannel: "请选择信道 6、43 或 68。"
        case .notConnected: "请先连接串口。"
        case .busy: "串口被其他程序占用。"
        case .system(let text): text
        case .writeTimeout: "串口写入超时。"
        case .unexpectedReply: "模块没有返回可识别的成功响应；已停止后续配置，请查询参数。"
        case .cancelled: "操作已取消。"
        }
    }
}
public extension Data {
    var hex: String { map { String(format:"%02X",$0) }.joined(separator:" ") }
}
