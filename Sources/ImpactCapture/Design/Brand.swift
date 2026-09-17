import AppKit
import ImpactCaptureCore
import SwiftUI

/// Impact Capture's visual language: warm paper in light mode, ink in dark mode, one coral "spark"
/// accent, monospaced metadata. Serious enough for work, with a wink for engineers.
enum Brand {
    static let spark = Color(hex: 0xFF6A3D)
    /// Text and marks drawn on top of `spark`.
    static let onSpark = Color(hex: 0x14161B)

    static let background = Color.dynamic(light: 0xF6F4EF, dark: 0x111318)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x1A1D24)
    static let raised = Color.dynamic(light: 0xEEEBE4, dark: 0x252933)
    static let hairline = Color.dynamic(light: 0xE3DFD6, dark: 0x2D323D)
    static let text = Color.dynamic(light: 0x14161B, dark: 0xF3F1EC)
    static let secondaryText = Color.dynamic(light: 0x5B616C, dark: 0xA0A6B2)
    static let tertiaryText = Color.dynamic(light: 0x8C919A, dark: 0x6C7380)
    static let danger = Color.dynamic(light: 0xD23B27, dark: 0xFF7A66)
    static let success = Color.dynamic(light: 0x2E9E5B, dark: 0x5BD48C)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    static func color(_ color: CategoryColor) -> Color {
        switch color {
        case .coral: return Color(hex: 0xFF6A3D)
        case .amber: return Color(hex: 0xF5A524)
        case .lime: return Color(hex: 0x6DBE45)
        case .teal: return Color(hex: 0x22B8A7)
        case .sky: return Color(hex: 0x3E9BFF)
        case .violet: return Color(hex: 0x8F6BFF)
        case .pink: return Color(hex: 0xF0609E)
        case .slate: return Color(hex: 0x8791A3)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// The mark: a capture ring with a gap and a spark escaping through it.
struct LogoMark: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Brand.spark)
            Circle()
                .trim(from: 0, to: 0.86)
                .stroke(Brand.onSpark, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-25))
                .frame(width: size * 0.54, height: size * 0.54)
            Circle()
                .fill(Brand.onSpark)
                .frame(width: size * 0.18, height: size * 0.18)
            Circle()
                .fill(Brand.onSpark)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: size * 0.27 * 0.62, y: -size * 0.27 * 0.78)
        }
        .frame(width: size, height: size)
    }
}

enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let center = NSPoint(x: 9, y: 9)
            let radius: CGFloat = 6.2

            let ring = NSBezierPath()
            ring.appendArc(withCenter: center, radius: radius, startAngle: 62, endAngle: 30, clockwise: false)
            ring.lineWidth = 1.8
            ring.lineCapStyle = .round
            ring.stroke()

            NSBezierPath(ovalIn: NSRect(x: center.x - 2.3, y: center.y - 2.3, width: 4.6, height: 4.6)).fill()

            let angle = 46 * CGFloat.pi / 180
            let spark = NSPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            NSBezierPath(ovalIn: NSRect(x: spark.x - 1.25, y: spark.y - 1.25, width: 2.5, height: 2.5)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
