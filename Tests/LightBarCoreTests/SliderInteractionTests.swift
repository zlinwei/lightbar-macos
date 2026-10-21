// SPDX-License-Identifier: GPL-3.0-only
import XCTest
import LightBarCore
@testable import MiLightBar

final class SliderInteractionTests: XCTestCase, @unchecked Sendable {
    @MainActor func testDraggingDoesNotSendAndReleaseRoundsFinalValue() async throws {
        let model = AppModel(demo:true)
        model.connected = true; model.configured = true
        model.editing(.brightness,changed:true)
        model.brightness = 2.2; model.valueChanged(.brightness)
        model.brightness = 11.7; model.valueChanged(.brightness)
        try await Task.sleep(for:.milliseconds(240))
        XCTAssertEqual(model.entries.filter{$0.kind == "灯包"}.count,0)
        model.editing(.brightness,changed:false)
        try await Task.sleep(for:.milliseconds(90))
        XCTAssertEqual(model.entries.filter{$0.kind == "灯包"}.count,2)
        XCTAssertTrue(model.status.contains("12/15"))
        model.disconnect()
    }
    @MainActor func testRapidReleaseCoalescesAndKeyboardCommitsWithoutApply() async throws {
        let model = AppModel(demo:true)
        model.connected = true; model.configured = true
        model.brightness = 2; model.editing(.brightness,changed:false)
        try await Task.sleep(for:.milliseconds(40))
        model.brightness = 4; model.editing(.brightness,changed:false)
        model.brightness = 9; model.editing(.brightness,changed:false)
        model.brightness = 14.3; model.editing(.brightness,changed:false)
        try await Task.sleep(for:.milliseconds(80))
        XCTAssertEqual(model.entries.filter{$0.kind == "灯包"}.count,2)
        try await Task.sleep(for:.milliseconds(320))
        XCTAssertEqual(model.entries.filter{$0.kind == "灯包"}.count,4)
        XCTAssertTrue(model.status.contains("14/15"))
        let sends = model.entries.filter{$0.kind == "发送"}
        XCTAssertGreaterThanOrEqual(sends[1].date.timeIntervalSince(sends[0].date),0.33)
        model.temperature = 5.7; model.valueChanged(.temperature)
        try await Task.sleep(for:.milliseconds(420))
        XCTAssertTrue(model.status.contains("6/15"))
        model.disconnect()
    }
}
