// SPDX-License-Identifier: GPL-3.0-only
// Vector-drawn, original macOS app icon. No downloaded or trademark assets.
import AppKit
import Foundation

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/icon"
try FileManager.default.createDirectory(atPath:output,withIntermediateDirectories:true)
func rounded(_ rect: NSRect,_ radius: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect:rect,xRadius:radius,yRadius:radius) }
func color(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat,_ a: CGFloat = 1) -> NSColor { NSColor(srgbRed:r,green:g,blue:b,alpha:a) }
func fill(_ path: NSBezierPath,_ color: NSColor) { color.setFill(); path.fill() }
func paint() {
    let tile = rounded(NSRect(x:32,y:32,width:960,height:960),214)
    NSGradient(starting:color(0.13,0.17,0.22),ending:color(0.045,0.065,0.09))!.draw(in:tile,angle:-90)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    let beam = NSBezierPath(); beam.move(to:NSPoint(x:190,y:704));beam.line(to:NSPoint(x:820,y:704));beam.line(to:NSPoint(x:900,y:220));beam.line(to:NSPoint(x:125,y:220));beam.close()
    NSGradient(starting:color(1,0.72,0.30,0.18),ending:color(1,0.54,0.12,0))!.draw(in:beam,angle:-90)
    let screen = rounded(NSRect(x:235,y:315,width:554,height:340),34)
    NSGradient(starting:color(0.22,0.27,0.32),ending:color(0.09,0.12,0.16))!.draw(in:screen,angle:-90)
    screen.lineWidth = 14; color(0.55,0.60,0.64).setStroke();screen.stroke()
    fill(rounded(NSRect(x:482,y:220,width:60,height:87),12),color(0.37,0.42,0.46))
    fill(rounded(NSRect(x:375,y:198,width:274,height:28),14),color(0.53,0.58,0.61))
    fill(rounded(NSRect(x:475,y:654,width:74,height:70),17),color(0.29,0.33,0.37))
    let bar = rounded(NSRect(x:144,y:706,width:736,height:64),32)
    let shadow = NSShadow();shadow.shadowColor = color(0,0,0,0.5);shadow.shadowBlurRadius = 22;shadow.shadowOffset = NSSize(width:0,height:-8)
    NSGraphicsContext.saveGraphicsState();shadow.set()
    NSGradient(starting:color(0.84,0.87,0.88),ending:color(0.42,0.48,0.53))!.draw(in:bar,angle:-90)
    NSGraphicsContext.restoreGraphicsState()
    fill(rounded(NSRect(x:171,y:704,width:682,height:12),6),color(1,0.77,0.36))
    fill(rounded(NSRect(x:180,y:750,width:660,height:5),2.5),color(1,1,1,0.45))
    let reflection = NSBezierPath();reflection.move(to:NSPoint(x:267,y:615));reflection.line(to:NSPoint(x:756,y:615));reflection.lineWidth=3;color(1,0.79,0.46,0.28).setStroke();reflection.stroke()
    NSGraphicsContext.restoreGraphicsState()
}
let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
bitmap.size = NSSize(width:1024,height:1024)
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap);paint();NSGraphicsContext.restoreGraphicsState()
let master = NSImage(size:NSSize(width:1024,height:1024));master.addRepresentation(bitmap)
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output+"/AppIcon-1024.png"))
let set = output+"/AppIcon.iconset";try FileManager.default.createDirectory(atPath:set,withIntermediateDirectories:true)
for points in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels = points*scale
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        rep.size = NSSize(width:points,height:points)
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        master.draw(in:NSRect(x:0,y:0,width:points,height:points))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(points)x\(points)"+(scale==2 ? "@2x" : "")+".png"
        try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:set+"/"+name))
    }
}
