// SPDX-License-Identifier: GPL-3.0-only
import XCTest
@testable import LightBarCore

final class ControlQueueTests: XCTestCase {
    func testLatestTargetWinsWhileOtherControlIsPreserved() throws {
        var queue = ControlQueue()
        queue.enqueue(.brightness(2)); queue.enqueue(.temperature(4)); queue.enqueue(.brightness(12))
        XCTAssertEqual(queue.count,2)
        XCTAssertEqual(queue.next()?.level,12)
        XCTAssertEqual(queue.next()?.level,4)
        XCTAssertTrue(queue.isEmpty)
    }
    func testEditingSuppressesOnlyItsOwnTarget() {
        var queue = ControlQueue()
        queue.enqueue(.brightness(3)); queue.enqueue(.temperature(9))
        XCTAssertEqual(queue.next(excluding:[.brightness])?.absolute,.temperature)
        XCTAssertNil(queue.next(excluding:[.brightness]))
        XCTAssertEqual(queue.count,1)
        queue.remove(.brightness)
        queue.enqueue(.brightness(14))
        XCTAssertEqual(queue.next()?.level,14)
    }
    func testMicroClicksAreFixedSingleStepsInOrder() throws {
        var queue = ControlQueue()
        queue.enqueue(.command(.dimmer(1))); queue.enqueue(.command(.brighter(1))); queue.enqueue(.command(.brighter(1)))
        XCTAssertEqual(queue.count,3)
        XCTAssertEqual(try queue.next()?.codes(),[0x04FF])
        XCTAssertEqual(try queue.next()?.codes(),[0x0401])
        XCTAssertEqual(try queue.next()?.codes(),[0x0401])
    }
    func testContinuousValuesRoundAndClamp() {
        XCTAssertEqual(ControlIntent.roundedLevel(7.49),7)
        XCTAssertEqual(ControlIntent.roundedLevel(7.5),8)
        XCTAssertEqual(ControlIntent.roundedLevel(-100),0)
        XCTAssertEqual(ControlIntent.roundedLevel(999),15)
        XCTAssertEqual(ControlIntent.roundedLevel(.nan),8)
    }
    func testMinimumStartIntervalUsesMonotonicClock() {
        let start = ContinuousClock.now
        XCTAssertEqual(SendTiming.remaining(since:nil,now:start),.zero)
        XCTAssertEqual(SendTiming.remaining(since:start,now:start),.milliseconds(350))
        XCTAssertEqual(SendTiming.remaining(since:start,now:start.advanced(by:.milliseconds(200))),.milliseconds(150))
        XCTAssertEqual(SendTiming.remaining(since:start,now:start.advanced(by:.seconds(2))),.zero)
    }
}
