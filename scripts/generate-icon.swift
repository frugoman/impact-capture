#!/usr/bin/env swift
// Renders the app icon (capture ring + escaping spark on ink) into the asset catalog.
// Usage: swift scripts/generate-icon.swift

import AppKit

let outputDirectory = URL(fileURLWithPath: "Sources/ImpactCapture/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(pixels) / 1024
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: scale, y: scale)

    // macOS icon grid: 824pt body centered in 1024 with a soft shadow.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0x14161B).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(starting: color(0x262A34), ending: color(0x0E1014))!.draw(in: shape, angle: -90)

    let center = NSPoint(x: 512, y: 512)
    let radius: CGFloat = 238
    let spark = color(0xFF6A3D)

    // Faint orbit behind the ring.
    let orbit = NSBezierPath(ovalIn: NSRect(x: center.x - 318, y: center.y - 318, width: 636, height: 636))
    orbit.lineWidth = 3
    spark.withAlphaComponent(0.12).setStroke()
    orbit.stroke()

    let ring = NSBezierPath()
    ring.appendArc(withCenter: center, radius: radius, startAngle: 68, endAngle: 24, clockwise: false)
    ring.lineWidth = 64
    ring.lineCapStyle = .round
    spark.setStroke()
    ring.stroke()

    spark.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 88, y: center.y - 88, width: 176, height: 176)).fill()

    // The spark escaping through the gap.
    let angle = 46 * CGFloat.pi / 180
    let sparkCenter = NSPoint(x: center.x + (radius + 70) * cos(angle), y: center.y + (radius + 70) * sin(angle))
    color(0xFFB08F).setFill()
    NSBezierPath(ovalIn: NSRect(x: sparkCenter.x - 38, y: sparkCenter.y - 38, width: 76, height: 76)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let entries: [(size: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

var images: [[String: String]] = []
for entry in entries {
    let pixels = entry.size * entry.scale
    let name = "icon_\(entry.size)x\(entry.size)\(entry.scale == 2 ? "@2x" : "").png"
    try render(pixels: pixels).write(to: outputDirectory.appendingPathComponent(name))
    images.append(["idiom": "mac", "size": "\(entry.size)x\(entry.size)", "scale": "\(entry.scale)x", "filename": name])
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: outputDirectory.appendingPathComponent("Contents.json"))
try #"{"info":{"author":"xcode","version":1}}"#
    .write(to: outputDirectory.deletingLastPathComponent().appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Wrote \(entries.count) icons to \(outputDirectory.path)")
