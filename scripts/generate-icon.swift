#!/usr/bin/swift
// Generates PhotoExodus app icon at all required macOS sizes.
// Design: gradient background with a stylized photo + arrow motif.

import AppKit
import CoreGraphics

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size // shorthand
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // --- Background gradient (deep indigo → teal) ---
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.18, green: 0.12, blue: 0.56, alpha: 1.0),  // deep indigo
        CGColor(red: 0.10, green: 0.45, blue: 0.65, alpha: 1.0),  // teal-blue
    ] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: s),
            end: CGPoint(x: s, y: 0),
            options: []
        )
    }

    // --- Polaroid / photo frame ---
    let frameW = s * 0.52
    let frameH = s * 0.58
    let frameX = s * 0.14
    let frameY = s * 0.22

    // Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: s * 0.01, height: -s * 0.02), blur: s * 0.04,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))

    // White frame with slight rotation
    ctx.saveGState()
    ctx.translateBy(x: frameX + frameW / 2, y: frameY + frameH / 2)
    ctx.rotate(by: -0.08) // slight tilt
    let frameRect = CGRect(x: -frameW / 2, y: -frameH / 2, width: frameW, height: frameH)
    let cornerRadius = s * 0.02
    let framePath = CGPath(roundedRect: frameRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.addPath(framePath)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.restoreGState()

    // Photo "image" area inside the frame (darker area representing the photo)
    ctx.saveGState()
    ctx.translateBy(x: frameX + frameW / 2, y: frameY + frameH / 2)
    ctx.rotate(by: -0.08)
    let photoInset = s * 0.03
    let photoBottom = s * 0.10 // polaroid has more space at bottom
    let photoRect = CGRect(
        x: -frameW / 2 + photoInset,
        y: -frameH / 2 + photoBottom,
        width: frameW - photoInset * 2,
        height: frameH - photoInset - photoBottom
    )

    // Mini gradient for the "photo" area (landscape feel)
    let photoColors = [
        CGColor(red: 0.55, green: 0.78, blue: 0.92, alpha: 1.0),  // sky blue
        CGColor(red: 0.30, green: 0.65, blue: 0.45, alpha: 1.0),  // green
    ] as CFArray
    ctx.clip(to: photoRect)
    if let photoGrad = CGGradient(colorsSpace: colorSpace, colors: photoColors, locations: locations) {
        ctx.drawLinearGradient(
            photoGrad,
            start: CGPoint(x: photoRect.minX, y: photoRect.maxY),
            end: CGPoint(x: photoRect.minX, y: photoRect.minY),
            options: []
        )
    }

    // Simple mountain silhouette in the photo
    ctx.resetClip()
    ctx.setFillColor(CGColor(red: 0.22, green: 0.50, blue: 0.35, alpha: 1.0))
    let mountainPath = CGMutablePath()
    let mBaseY = photoRect.minY + photoRect.height * 0.15
    mountainPath.move(to: CGPoint(x: photoRect.minX, y: mBaseY))
    mountainPath.addLine(to: CGPoint(x: photoRect.minX + photoRect.width * 0.3, y: photoRect.minY + photoRect.height * 0.65))
    mountainPath.addLine(to: CGPoint(x: photoRect.minX + photoRect.width * 0.45, y: photoRect.minY + photoRect.height * 0.45))
    mountainPath.addLine(to: CGPoint(x: photoRect.minX + photoRect.width * 0.7, y: photoRect.minY + photoRect.height * 0.75))
    mountainPath.addLine(to: CGPoint(x: photoRect.maxX, y: mBaseY))
    mountainPath.closeSubpath()
    ctx.addPath(mountainPath)
    ctx.fillPath()

    // Sun circle in the photo
    let sunR = photoRect.width * 0.08
    let sunCenter = CGPoint(x: photoRect.maxX - photoRect.width * 0.25, y: photoRect.maxY - photoRect.height * 0.25)
    ctx.setFillColor(CGColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: sunCenter.x - sunR, y: sunCenter.y - sunR, width: sunR * 2, height: sunR * 2))

    ctx.restoreGState()

    // --- Arrow (migration/exodus motif) ---
    // Curved arrow from right side, sweeping upward
    ctx.saveGState()
    let arrowColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
    ctx.setStrokeColor(arrowColor)
    ctx.setFillColor(arrowColor)
    ctx.setLineWidth(s * 0.028)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Arrow arc path
    let arrowPath = CGMutablePath()
    let arcStartX = s * 0.58
    let arcStartY = s * 0.20
    let arcEndX = s * 0.82
    let arcEndY = s * 0.62

    arrowPath.move(to: CGPoint(x: arcStartX, y: arcStartY))
    arrowPath.addQuadCurve(
        to: CGPoint(x: arcEndX, y: arcEndY),
        control: CGPoint(x: s * 0.88, y: s * 0.28)
    )
    ctx.addPath(arrowPath)
    ctx.strokePath()

    // Arrowhead at the end
    let headSize = s * 0.06
    let headPath = CGMutablePath()
    headPath.move(to: CGPoint(x: arcEndX, y: arcEndY))
    headPath.addLine(to: CGPoint(x: arcEndX - headSize * 0.3, y: arcEndY - headSize))
    headPath.addLine(to: CGPoint(x: arcEndX + headSize * 0.8, y: arcEndY - headSize * 0.4))
    headPath.closeSubpath()
    ctx.addPath(headPath)
    ctx.fillPath()

    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// --- Generate all required sizes ---
let assetDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/Assets.xcassets/AppIcon.appiconset"

// macOS icon sizes: point size × scale → pixel size
let specs: [(name: String, pixels: Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x",1024),
]

// Draw at 1024 and resize down for crispness
let master = drawIcon(size: 1024)

for spec in specs {
    let resized = NSImage(size: NSSize(width: spec.pixels, height: spec.pixels))
    resized.lockFocus()
    master.draw(
        in: NSRect(x: 0, y: 0, width: spec.pixels, height: spec.pixels),
        from: NSRect(x: 0, y: 0, width: 1024, height: 1024),
        operation: .copy,
        fraction: 1.0
    )
    resized.unlockFocus()

    let path = "\(assetDir)/\(spec.name).png"
    savePNG(resized, to: path)
    print("  \(spec.name).png (\(spec.pixels)×\(spec.pixels))")
}

print("Done! Generated \(specs.count) icon sizes.")
