// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import SwiftUI

@main
struct MiLightBarApp: App {
    @NSApplicationDelegateAdaptor(LampApplicationDelegate.self) private var applicationDelegate
    private let model = AppModel(demo:CommandLine.arguments.contains("--demo"))
    var body: some Scene {
        Window("米家挂灯",id:"light-control") {
            ContentView(model:model)
                .background(MainWindowRegistration(applicationDelegate:applicationDelegate))
                .onAppear { NSApplication.shared.activate(ignoringOtherApps:true) }
                .tint(LampTheme.accent)
                .preferredColorScheme(CommandLine.arguments.contains("--dark-preview") ? .dark : CommandLine.arguments.contains("--light-preview") ? .light : nil)
        }
        .defaultSize(width:500,height:640)
        .windowResizability(.contentMinSize)
        .commands { CommandGroup(replacing:.newItem) {} }
        Settings { SettingsView(model:model) }
    }
}
