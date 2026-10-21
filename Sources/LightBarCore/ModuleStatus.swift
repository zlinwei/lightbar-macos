// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import CoreFoundation

/// Parses the documented AT? reply once; missing/unknown fields remain nil.
public struct ModuleStatus: Sendable {
    public let transmitAddress: [UInt8]?
    public let frequencyMHz: Int?
    public let crcBits: Int?
    public let rateKbps: Int?
    public init(reply: Data) {
        var fields: [String:String] = [:]
        for line in ModuleProtocol.replyText(reply).components(separatedBy:.newlines) {
            let parts = line.replacingOccurrences(of:"：",with:":").split(separator:":",maxSplits:1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in:.whitespaces)
            // Duplicated status fields are ambiguous, not last-write-wins.
            let value = parts[1].trimmingCharacters(in:.whitespaces)
            fields[key] = fields[key] == nil ? value : ""
        }
        let address = fields["目标地址"]?.split(separator:",",omittingEmptySubsequences:false)
        if let address, address.count == 5 {
            let parsed = address.compactMap { part -> UInt8? in
                let text = part.trimmingCharacters(in:.whitespaces)
                guard text.count == 4, text.lowercased().hasPrefix("0x") else { return nil }
                return UInt8(text.dropFirst(2),radix:16)
            }
            transmitAddress = parsed.count == 5 ? parsed : nil
        } else { transmitAddress = nil }
        let frequency = (fields["通信频率"] ?? fields["通讯频率"])?.lowercased()
        if let frequency, frequency.range(of:"^2\\.[0-9]{3}ghz$",options:.regularExpression) != nil {
            frequencyMHz = Int(frequency.replacingOccurrences(of:"ghz",with:"").replacingOccurrences(of:".",with:""))
        } else { frequencyMHz = nil }
        let crc = fields["校验方式"]?.replacingOccurrences(of:" ",with:"")
        if let crc, crc.range(of:"^[0-9]+位CRC校验$",options:.regularExpression) != nil {
            crcBits = Int(crc.prefix(while:{$0.isNumber}))
        } else { crcBits = nil }
        switch fields["空中传输速率"]?.lowercased() {
        case "2mbps": rateKbps = 2000
        case "1mbps": rateKbps = 1000
        case "250kbps": rateKbps = 250
        default: rateKbps = nil
        }
    }
    /// All documented identifying fields must be understood before writing configuration.
    public var isRecognized: Bool {
        transmitAddress != nil && frequencyMHz != nil && crcBits != nil && rateKbps != nil
    }
    public func matchesLightBar(channel: Int) -> Bool {
        transmitAddress == Array(repeating:0x55,count:5) && frequencyMHz == 2400 + channel && crcBits == 16 && rateKbps == 2000
    }
}
public extension ModuleProtocol {
    static func replyText(_ data: Data) -> String {
        if let utf = String(data:data,encoding:.utf8) { return utf }
        let gb = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        return String(data:data,encoding:String.Encoding(rawValue:gb)) ?? data.hex
    }
}
