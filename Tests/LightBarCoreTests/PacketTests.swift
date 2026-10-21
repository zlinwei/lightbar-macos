// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import XCTest
@testable import LightBarCore

final class PacketTests: XCTestCase, @unchecked Sendable {
func testCapturedRemoteVectors() throws {
    let fixtures: [(UInt8, String)] = [
        (0x79,"533914DD1C49341201B960FF7901003870"),
        (0x16,"533914DD1C49341201B960FF1601008F2A"),
        (0x1A,"533914DD1C49341201B960FF1A0100FA4B"),
        (0x20,"533914DD1C49341201B960FF200100F82F")]
    for (counter, hex) in fixtures {
        let packet = try LightBarPacket.make(remoteID:0x01B960,code:0x0100,counter:counter)
        XCTAssertTrue(packet.count == 17)
        XCTAssertTrue(packet.hex.replacingOccurrences(of:" ",with:"") == hex)
        XCTAssertTrue(LightBarPacket.crc16(Array(packet)) == 0)
    }
}
func testCrcCheckValue() { XCTAssertTrue(LightBarPacket.crc16(Array("123456789".utf8)) == 0x6E62) }
func testRejectsMalformedInputs() throws {
    XCTAssertThrowsError(try LightBarPacket.remoteID("ABCDE"))
    XCTAssertThrowsError(try LightBarPacket.remoteID("12345G"))
    XCTAssertThrowsError(try LightBarPacket.make(remoteID:0x1000000,code:0,counter:0))
    XCTAssertThrowsError(try LightCommand.dimmer(0).code())
    XCTAssertThrowsError(try LightCommand.warmer(-1).code())
    XCTAssertThrowsError(try LightCommand.warmer(Int.min).code())
    XCTAssertThrowsError(try LightBarPacket.absoluteBrightness(16))
    XCTAssertThrowsError(try LightBarPacket.absoluteTemperature(-1))
    XCTAssertTrue(try LightBarPacket.remoteID("a1B2c3") == 0xA1B2C3)
}
func testDirectionalCodes() throws {
    XCTAssertTrue(try LightCommand.toggle.code() == 0x0100)
    XCTAssertTrue(try LightCommand.reset.code() == 0x0600)
    XCTAssertTrue(try LightCommand.brighter(15).code() == 0x040F)
    XCTAssertTrue(try LightCommand.dimmer(1).code() == 0x04FF)
    XCTAssertTrue(try LightCommand.cooler(1).code() == 0x0201)
    XCTAssertTrue(try LightCommand.warmer(15).code() == 0x02F1)
}
func testAbsoluteUsesTwoDistinctOperations() throws {
    XCTAssertTrue(try LightBarPacket.absoluteBrightness(0) == [0x04F0,0x0400])
    XCTAssertTrue(try LightBarPacket.absoluteBrightness(15) == [0x04F0,0x040F])
    XCTAssertTrue(try LightBarPacket.absoluteTemperature(15) == [0x02F0,0x020F])
}
func testModuleCommandsMatchManual() throws {
    XCTAssertTrue(String(data:ModuleProtocol.query,encoding:.utf8) == "AT?")
    XCTAssertTrue(String(data:ModuleProtocol.version,encoding:.utf8) == "AT+VER")
    XCTAssertTrue(try ModuleProtocol.configure(channel:6).map{String(decoding:$0,as:UTF8.self)} == ["AT+RATE=3","AT+CRC=16","AT+TXA=0x55,0x55,0x55,0x55,0x55","AT+FREQ=2.406G"])
    XCTAssertTrue(try ModuleProtocol.configure(channel:43).last == Data("AT+FREQ=2.443G".utf8))
    XCTAssertTrue(try ModuleProtocol.configure(channel:68).last == Data("AT+FREQ=2.468G".utf8))
    XCTAssertThrowsError(try ModuleProtocol.configure(channel:125))
}

func testRejectsUnsafeSerialArgumentsWithoutHardware() async {
    let port = SerialPort()
    for path in ["/etc/passwd", "/dev/cu.fake/child", "/dev/cu.fake\0suffix"] {
        do { try await port.connect(path:path); XCTFail("Invalid path accepted") }
        catch ModuleError.system(let message) { XCTAssertEqual(message,"无效串口路径。") }
        catch { XCTFail("Unexpected error: \(error)") }
    }
    for repetitions in [Int.min, -1, 0, 31, Int.max] {
        do { _ = try await port.transmit(packets:[],repetitions:repetitions); XCTFail("Invalid repetitions accepted") }
        catch ModuleError.system(let message) { XCTAssertEqual(message,"重复次数必须在 1…30 之间。") }
        catch { XCTFail("Unexpected error: \(error)") }
    }
}

func testHardwareReadOnlyQuery() async throws {
    guard let path = ProcessInfo.processInfo.environment["LIGHTBAR_TEST_SERIAL"] else { throw XCTSkip("Set LIGHTBAR_TEST_SERIAL for real module query") }
    let port = SerialPort()
    try await port.connect(path:path)
    do {
        let info = try await port.exchange(ModuleProtocol.query,waitMilliseconds:800)
        let version = try await port.exchange(ModuleProtocol.version,waitMilliseconds:800)
        await port.disconnect()
        XCTAssertTrue(info.range(of:Data("OK".utf8)) != nil)
        XCTAssertTrue(info.range(of:Data("115200".utf8)) != nil)
        XCTAssertTrue(ModuleStatus(reply:info).matchesLightBar(channel:6))
        XCTAssertTrue(version.range(of:Data("Ver".utf8)) != nil)
    } catch { await port.disconnect(); throw error }
}

func testParsesActualModuleStatusAndUnknowns() {
    let text = "OK\r\n目标地址：0x55,0x55,0x55,0x55,0x55\r\n本机接收地址0：0x11,0x22,0x33,0x44,0x55\r\n通信频率：2.406GHz\r\n校验方式: 16位CRC校验\r\n空中传输速率：2Mbps\r\n"
    XCTAssertTrue(ModuleStatus(reply:Data(text.utf8)).isRecognized)
    XCTAssertFalse(ModuleStatus(reply:Data("OK".utf8)).isRecognized)
    XCTAssertTrue(ModuleStatus(reply:Data(text.utf8)).matchesLightBar(channel:6))
    XCTAssertTrue(!ModuleStatus(reply:Data(text.utf8)).matchesLightBar(channel:43))
    XCTAssertTrue(!ModuleStatus(reply:Data("OK".utf8)).matchesLightBar(channel:6))
    XCTAssertTrue(!ModuleStatus(reply:Data((text+"目标地址：0x55,0x55,0x55,0x55,0x55\n").utf8)).matchesLightBar(channel:6))
    XCTAssertTrue(!ModuleStatus(reply:Data(text.replacingOccurrences(of:"16位",with:"116位").utf8)).matchesLightBar(channel:6))
    XCTAssertTrue(!ModuleStatus(reply:Data(text.replacingOccurrences(of:"0x55,0x55,0x55,0x55,0x55",with:"0x55,0x55,0x55,0x55").utf8)).matchesLightBar(channel:6))
    let gb = Data([0xCD,0xA8,0xD0,0xC5,0xC6,0xB5,0xC2,0xCA])
    XCTAssertTrue(ModuleProtocol.replyText(gb) == "通信频率")
}

}
