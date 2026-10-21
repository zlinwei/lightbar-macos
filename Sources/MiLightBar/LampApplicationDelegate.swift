// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import SwiftUI

/// Owns the menu bar entry and the lifetime of the single control window.
@MainActor
final class LampApplicationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private weak var controlWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName:"lightbulb",accessibilityDescription:"米家挂灯")
            button.toolTip = "米家挂灯 · 点击打开控制窗口"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on:[.leftMouseUp,.rightMouseUp])
        }
        statusItem = item
    }

    func register(_ window: NSWindow) {
        controlWindow = window
        window.delegate = self
        window.isReleasedWhenClosed = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === controlWindow else { return true }
        sender.orderOut(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControlWindow()
        return false
    }

    @objc func showControlWindow() {
        guard let window = controlWindow else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps:true)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApplication.shared.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let open = menu.addItem(withTitle:"打开米家挂灯",action:#selector(showControlWindow),keyEquivalent:"")
            open.target = self
            menu.addItem(.separator())
            let quit = menu.addItem(withTitle:"退出米家挂灯",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
            quit.target = NSApplication.shared
            menu.popUp(positioning:nil,at:NSPoint(x:0,y:sender.bounds.height + 4),in:sender)
        } else {
            showControlWindow()
        }
    }
}

struct MainWindowRegistration: NSViewRepresentable {
    let applicationDelegate: LampApplicationDelegate
    func makeNSView(context: Context) -> WindowRegistrationView {
        WindowRegistrationView(applicationDelegate:applicationDelegate)
    }
    func updateNSView(_ nsView: WindowRegistrationView, context: Context) {}
}

final class WindowRegistrationView: NSView {
    private let applicationDelegate: LampApplicationDelegate
    init(applicationDelegate: LampApplicationDelegate) {
        self.applicationDelegate = applicationDelegate
        super.init(frame:.zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { applicationDelegate.register(window) }
    }
}
