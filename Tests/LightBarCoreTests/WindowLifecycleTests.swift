// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import XCTest
@testable import MiLightBar

final class WindowLifecycleTests: XCTestCase, @unchecked Sendable {
    @MainActor func testCloseHidesAndReopenRestoresSameWindow() {
        let application = NSApplication.shared
        let delegate = LampApplicationDelegate()
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:500,height:640),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        delegate.register(window)
        window.orderFront(nil)
        XCTAssertTrue(window.isVisible)
        window.performClose(nil)
        XCTAssertFalse(window.isVisible)
        XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(application))
        delegate.showControlWindow()
        XCTAssertTrue(window.isVisible)
        window.performClose(nil)
        XCTAssertFalse(window.isVisible)
        XCTAssertFalse(delegate.applicationShouldHandleReopen(application,hasVisibleWindows:false))
        XCTAssertTrue(window.isVisible)
        window.orderOut(nil)
    }
}
