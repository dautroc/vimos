#!/usr/bin/env swift
import Cocoa

// Configuration
let outputSize = CGSize(width: 1024, height: 1024)
let outputPath = "generated_vector_icon.png"
let backgroundColor = NSColor(white: 0.1, alpha: 1.0) // Dark Gray/Black
let strokeColor = NSColor.green

// Initialize Image
let image = NSImage(size: outputSize)
image.lockFocus()

// 1. Draw Background (Squircle-ish)
// macOS icons are actually full squares and the system masks them, 
// but to be safe and look good in preview we can draw a full square background.
backgroundColor.setFill()
NSRect(origin: .zero, size: outputSize).fill()

// 2. Draw Vector V
let ctx = NSGraphicsContext.current?.cgContext
ctx?.setLineWidth(80) // Scaled up line width (2.5 * ~32)
ctx?.setLineJoin(.round)
ctx?.setLineCap(.round)

let path = CGMutablePath()

// Original Coord [22x22] -> Target [1024x1024]
// Scale Factor: 1024 / 22 approx 46.5. Let's start with a safe margin.
// Let's assume the 22x22 canvas maps to the central 800x800 area to allow padding.

// V points: (6, 16) -> (11, 6) -> (16, 16) (In Menu Bar coords where Y is down? Wait, Cocoa is Y up?)
// In AppDelegate `flipped: false` was used? No, default is false (Y up).
// `path.move(to: CGPoint(x: 6, y: 16))` (Top Leftish)
// `path.addLine(to: CGPoint(x: 11, y: 6))` (Bottom Center)
// `path.addLine(to: CGPoint(x: 16, y: 16))` (Top Rightish)
// So 16 is "High" Y, 6 is "Low" Y.
// In unflipped (Y up) context: 16 is higher on screen than 6. 
// So (11, 6) is the bottom tip. (6, 16) and (16, 16) are the top tips.
// Yes, that's a V.

// Mapping 0..22 to 0..1024
func map(_ val: CGFloat) -> CGFloat {
    // Center it.
    // Original range roughly 5..17 (width 12). Center 11. 
    // Target width 1024. Center 512.
    // Scale: let's make the V big. 800px wide.
    // 12 units -> 800 px => Scale ~ 66.
    let scale: CGFloat = 70.0
    let center: CGFloat = 11.0
    return 512 + (val - center) * scale
}

// Draw
path.move(to: CGPoint(x: map(6), y: map(16)))
path.addLine(to: CGPoint(x: map(11), y: map(6)))
path.addLine(to: CGPoint(x: map(16), y: map(16)))

ctx?.addPath(path)
strokeColor.setStroke()
ctx?.strokePath()

image.unlockFocus()

// Save to PNG
if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Generated \(outputPath)")
} else {
    print("Failed to generate image data")
    exit(1)
}
