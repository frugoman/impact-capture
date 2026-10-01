import AppKit
import ImpactCaptureCore
import SwiftUI

/// Impact Capture's visual language: a notebook, not a dashboard. Cool ruled paper in light mode, night ink in
/// dark mode, and one highlighter yellow for the moments worth keeping. Display type is set wide (SF Expanded),
/// times and Markdown in mono.
enum Brand {
    /// The highlighter. Fills only (buttons, marks, selected states); never text on paper.
    static let highlighter = Color(hex: 0xFFDE3B)
    /// Text and marks drawn on top of `highlighter`, in both appearances.
    static let onHighlighter = Color(hex: 0x14183A)

    /// The interactive accent for tints, strokes and foreground marks: ballpoint blue on paper, highlighter at night.
    static let spark = Color.dynamic(light: 0x3340DB, dark: 0xFFDE3B)
    /// Text and marks drawn on top of `spark`.
    static let onSpark = Color.dynamic(light: 0xFFFFFF, dark: 0x14183A)

    static let background = Color.dynamic(light: 0xF0F1F6, dark: 0x0D1020)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x161A2E)
    static let raised = Color.dynamic(light: 0xE4E6EF, dark: 0x21263F)
    static let hairline = Color.dynamic(light: 0xD8DBE7, dark: 0x2A3050)
    static let grid = Color.dynamic(light: 0xC9CDDD, dark: 0x262C4A)
    static let text = Color.dynamic(light: 0x14183A, dark: 0xEEF0FA)
    static let secondaryText = Color.dynamic(light: 0x4F5577, dark: 0xA4AACB)
    static let tertiaryText = Color.dynamic(light: 0x868BA6, dark: 0x6A7097)
    static let danger = Color.dynamic(light: 0xD0342C, dark: 0xFF7A70)
    static let success = Color.dynamic(light: 0x23905A, dark: 0x5BD99A)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Headings and numbers: SF set wide, so titles read like a notebook's printed header.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }

    static func color(_ color: CategoryColor) -> Color {
        switch color {
        case .coral: return Color(hex: 0xFF6A4D)
        case .amber: return Color(hex: 0xF2A516)
        case .lime: return Color(hex: 0x5DBA3B)
        case .teal: return Color(hex: 0x1FB3A3)
        case .sky: return Color(hex: 0x3D8BFF)
        case .violet: return Color(hex: 0x8A63FF)
        case .pink: return Color(hex: 0xEE5598)
        case .slate: return Color(hex: 0x8790A8)
        }
    }

    static let springy = Animation.spring(response: 0.38, dampingFraction: 0.78)

    /// True while `SnapshotRenderer` draws screens to PNG, so entrance animations render in their final state.
    static var isRenderingSnapshot = false
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
                .fill(LinearGradient(colors: [Color(hex: 0x2A3170), Color(hex: 0x111433)], startPoint: .top, endPoint: .bottom))
            Circle()
                .trim(from: 0, to: 0.86)
                .stroke(Brand.highlighter, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-25))
                .frame(width: size * 0.54, height: size * 0.54)
            Circle()
                .fill(Brand.highlighter)
                .frame(width: size * 0.18, height: size * 0.18)
            Circle()
                .fill(Brand.highlighter.opacity(0.7))
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

/// Dot-grid notebook paper, drawn behind the main surfaces.
struct PaperBackground: View {
    var spacing: CGFloat = 16

    var body: some View {
        Brand.background
            .overlay {
                Canvas { context, size in
                    let dot = CGSize(width: 1.4, height: 1.4)
                    var y = spacing / 2
                    while y < size.height {
                        var x = spacing / 2
                        while x < size.width {
                            context.fill(Path(ellipseIn: CGRect(origin: CGPoint(x: x, y: y), size: dot)), with: .color(Brand.grid))
                            x += spacing
                        }
                        y += spacing
                    }
                }
                .opacity(0.7)
                .allowsHitTesting(false)
            }
    }
}

/// A highlighter swipe: slightly slanted, ragged at the ends, like a real marker stroke.
struct HighlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let slant = rect.height * 0.12
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY + slant))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 1, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + slant * 0.3))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - slant), control: CGPoint(x: rect.maxX + 2, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.maxY - slant * 0.2))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 2, y: rect.minY + slant), control: CGPoint(x: rect.minX - 2, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

extension View {
    /// Draws a highlighter swipe behind the view. With `animated`, the swipe draws in left to right on appear.
    func highlighted(_ color: Color = Brand.highlighter, opacity: Double = 0.85, animated: Bool = false) -> some View {
        modifier(HighlightModifier(color: color, opacity: opacity, animated: animated))
    }
}

private struct HighlightModifier: ViewModifier {
    let color: Color
    let opacity: Double
    let animated: Bool
    @State private var progress: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 4)
            .background(alignment: .leading) {
                HighlightShape()
                    .fill(color.opacity(opacity))
                    .padding(.vertical, 1)
                    .scaleEffect(x: progress, y: 1, anchor: .leading)
            }
            .onAppear {
                guard animated, !Brand.isRenderingSnapshot else { return }
                progress = 0
                withAnimation(.easeOut(duration: 0.45).delay(0.1)) { progress = 1 }
            }
    }
}
