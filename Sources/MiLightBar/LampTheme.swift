// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import SwiftUI

@MainActor enum LampTheme {
    static var onAccent: Color {
        Color(nsColor:NSColor(name:nil) { appearance in
            appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
                ? NSColor(srgbRed:0.12,green:0.08,blue:0.03,alpha:1) : .white
        })
    }
    static var accent: Color {
        Color(nsColor:NSColor(name:nil) { appearance in
            let dark = appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
            return dark ? NSColor(srgbRed:0.95,green:0.65,blue:0.28,alpha:1) : NSColor(srgbRed:0.64,green:0.33,blue:0.07,alpha:1)
        })
    }
}
