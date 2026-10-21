// SPDX-License-Identifier: GPL-3.0-only
import Foundation

public enum AbsoluteControl: Hashable, Sendable { case brightness, temperature }
public enum ControlIntent: Sendable {
    case brightness(Int), temperature(Int), command(LightCommand)
    public var absolute: AbsoluteControl? {
        switch self { case .brightness: .brightness; case .temperature: .temperature; case .command: nil }
    }
    public var level: Int? {
        switch self { case .brightness(let value), .temperature(let value): value; case .command: nil }
    }
    public var affected: AbsoluteControl? {
        switch self {
        case .brightness, .command(.brighter), .command(.dimmer): .brightness
        case .temperature, .command(.warmer), .command(.cooler): .temperature
        default: nil
        }
    }
    public func codes() throws -> [UInt16] {
        switch self {
        case .brightness(let value): try LightBarPacket.absoluteBrightness(value)
        case .temperature(let value): try LightBarPacket.absoluteTemperature(value)
        case .command(let command): [try command.code()]
        }
    }
    public var label: String {
        switch self {
        case .brightness(let value): "亮度目标 \(value)/15"
        case .temperature(let value): "色温目标 \(value)/15"
        case .command(.toggle): "切换电源"
        case .command(.reset): "配对 / 长按复位"
        case .command(.brighter): "亮一点"
        case .command(.dimmer): "暗一点"
        case .command(.warmer): "暖一点"
        case .command(.cooler): "冷一点"
        }
    }
    public static func roundedLevel(_ value: Double) -> Int {
        guard value.isFinite else { return 8 }
        return Int(min(15,max(0,value)).rounded())
    }
}

/// One producer for coalescing: absolute targets replace unsent targets;
/// discrete button clicks preserve their order. An in-flight intent is immutable.
public struct ControlQueue: Sendable {
    private var pending: [ControlIntent] = []
    public init() {}
    public var count: Int { pending.count }
    public var isEmpty: Bool { pending.isEmpty }
    public mutating func enqueue(_ intent: ControlIntent) {
        if let key = intent.absolute, let index = pending.firstIndex(where:{$0.absolute == key}) {
            pending[index] = intent
        } else { pending.append(intent) }
    }
    public mutating func remove(_ control: AbsoluteControl) { pending.removeAll { $0.absolute == control } }
    public mutating func removeAll() { pending.removeAll() }
    public mutating func next(excluding: Set<AbsoluteControl> = []) -> ControlIntent? {
        guard let index = pending.firstIndex(where:{ intent in
            guard let key = intent.absolute else { return true }
            return !excluding.contains(key)
        }) else { return nil }
        return pending.remove(at:index)
    }
}

public enum SendTiming {
    public static let minimumStartInterval: Duration = .milliseconds(350)
    public static let keyboardDebounce: Duration = .milliseconds(180)
    public static func remaining(since previous: ContinuousClock.Instant?, now: ContinuousClock.Instant) -> Duration {
        guard let previous else { return .zero }
        return max(.zero,minimumStartInterval - previous.duration(to:now))
    }
}
