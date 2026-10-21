// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import SwiftUI
import XCTest
@testable import MiLightBar

final class AppearanceTests: XCTestCase, @unchecked Sendable {
    @MainActor func testRenderLightAndDarkControls() throws {
        guard let directory = ProcessInfo.processInfo.environment["LIGHTBAR_RENDER_PREVIEWS"] else {
            throw XCTSkip("Set LIGHTBAR_RENDER_PREVIEWS to render offscreen QA artifacts")
        }
        try FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        var images: [Data] = []
        for (name,scheme,appearance) in [("light",ColorScheme.light,NSAppearance.Name.aqua),("dark",ColorScheme.dark,NSAppearance.Name.darkAqua)] {
            let model = AppModel(demo:true); model.connected = true; model.configured = true
            let content = ContentView(model:model).tint(LampTheme.accent).environment(\.colorScheme,scheme).frame(width:500,height:640)
            let host = NSHostingView(rootView:content)
            host.appearance = NSAppearance(named:appearance)
            host.frame = NSRect(x:0,y:0,width:500,height:640)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in:host.bounds))
            host.cacheDisplay(in:host.bounds,to:bitmap)
            let png = try XCTUnwrap(bitmap.representation(using:.png,properties:[:]))
            XCTAssertGreaterThan(png.count,1000)
            try png.write(to:URL(fileURLWithPath:directory).appendingPathComponent(name+".png"))
            images.append(png)
        }
        XCTAssertNotEqual(images[0],images[1])
    }
}
