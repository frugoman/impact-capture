import ImpactCaptureCore
import SwiftUI

struct Wordmark: View {
    var showsTagline = true

    var body: some View {
        HStack(spacing: 10) {
            LogoMark(size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Impact Capture")
                    .font(Brand.display(14))
                    .foregroundStyle(Brand.text)
                if showsTagline {
                    Text("The work git doesn't see")
                        .font(.system(size: 11))
                        .foregroundStyle(Brand.tertiaryText)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.prefix(1).uppercased() + text.dropFirst())
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Brand.secondaryText)
    }
}

struct SparkButtonStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .foregroundStyle(Brand.onHighlighter)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 5 : 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Brand.highlighter)
                    .shadow(color: Color(hex: 0xB89A00).opacity(isEnabled ? 0.35 : 0), radius: 0, x: 0, y: configuration.isPressed ? 0 : 1.5)
            )
            .overlay(Capsule(style: .continuous).stroke(Color(hex: 0x14183A).opacity(0.12)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
}

struct QuietButtonStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundStyle(Brand.text)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 5 : 7)
            .background(
                Capsule(style: .continuous)
                    .fill(configuration.isPressed ? Brand.raised : Brand.surface)
            )
            .overlay(Capsule(style: .continuous).stroke(Brand.hairline))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
}

struct IconButton: View {
    let systemImage: String
    var help: String = ""
    var tint: Color = Brand.secondaryText
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? Brand.text : tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(isHovered ? Brand.raised : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Brand.mono(10.5, .medium))
            .foregroundStyle(Brand.secondaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Brand.raised))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Brand.hairline))
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Brand.hairline))
    }
}

struct CategoryChip: View {
    let name: String
    let color: Color
    let isSelected: Bool
    /// Draws the selection as a full-strength highlighter swipe with no colour dot, for choices that aren't categories.
    var solid = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if !solid {
                    Circle()
                        .fill(isSelected ? Brand.text.opacity(0.75) : color)
                        .frame(width: 6, height: 6)
                }
                Text(name)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? (solid ? Brand.onHighlighter : Brand.text) : Brand.secondaryText)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background {
                if isSelected {
                    HighlightShape()
                        .fill(solid ? Brand.highlighter : color.opacity(0.42))
                        .transition(.scale(scale: 0, anchor: .leading).combined(with: .opacity))
                }
            }
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Brand.hairline))
            .animation(.snappy(duration: 0.22), value: isSelected)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CategoryPicker: View {
    let categories: [CaptureCategory]
    @Binding var selection: String?

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(categories) { category in
                CategoryChip(
                    name: category.name,
                    color: Brand.color(category.color),
                    isSelected: selection == category.id
                ) {
                    selection = selection == category.id ? nil : category.id
                }
            }
        }
    }
}

struct MicButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording {
                    Circle()
                        .stroke(Brand.highlighter, lineWidth: 2)
                        .frame(width: 30, height: 30)
                        .scaleEffect(pulse ? 1.35 : 1)
                        .opacity(pulse ? 0 : 1)
                }
                Circle()
                    .fill(isRecording ? Brand.highlighter : Brand.surface)
                    .overlay(Circle().stroke(isRecording ? Color.clear : Brand.hairline))
                    .frame(width: 28, height: 28)
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: isRecording ? 10 : 12, weight: .semibold))
                    .foregroundStyle(isRecording ? Brand.onHighlighter : Brand.secondaryText)
            }
            .frame(width: 34, height: 34)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isRecording ? "Stop listening" : "Talk instead of typing")
        .onAppear { startPulse() }
        .onChange(of: isRecording) { startPulse() }
    }

    private func startPulse() {
        pulse = false
        guard isRecording else { return }
        withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}

/// Text box with dictation and category chips, shared by the popover and the check-in panel.
struct CaptureEditor: View {
    @Binding var text: String
    @Binding var categoryID: String?
    let categories: [CaptureCategory]
    @ObservedObject var transcriber: SpeechTranscriber
    var placeholder = "What happened?"
    var height: CGFloat = 80
    var autofocus = true
    let onToggleMic: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .foregroundStyle(Brand.text)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .padding(.leading, 5)
                    .padding(.trailing, 36)
                    .padding(.vertical, 7)
                if text.isEmpty {
                    Text(transcriber.isRecording ? "Listening…" : placeholder)
                        .font(.system(size: 13))
                        .foregroundStyle(transcriber.isRecording ? Brand.spark : Brand.tertiaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused || transcriber.isRecording ? Brand.spark : Brand.hairline, lineWidth: isFocused || transcriber.isRecording ? 1.5 : 1)
            )
            .shadow(color: Brand.spark.opacity(isFocused ? 0.14 : 0), radius: 6)
            .animation(.easeOut(duration: 0.15), value: isFocused)
            .overlay(alignment: .bottomTrailing) {
                MicButton(isRecording: transcriber.isRecording, action: onToggleMic)
                    .padding(3)
            }

            if let error = transcriber.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Brand.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !categories.isEmpty {
                CategoryPicker(categories: categories, selection: $categoryID)
            }
        }
        .onAppear {
            if autofocus {
                isFocused = true
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct Row {
        var y: CGFloat
        var height: CGFloat = 0
        var width: CGFloat = 0
        var items: [(index: Int, x: CGFloat, size: CGSize)] = []
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row(y: 0)]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            let x = row.items.isEmpty ? 0 : row.width + spacing
            if !row.items.isEmpty && x + size.width > maxWidth {
                row = Row(y: row.y + row.height + spacing)
                rows.append(row)
                rows[rows.count - 1].items.append((index, 0, size))
                rows[rows.count - 1].width = size.width
                rows[rows.count - 1].height = size.height
            } else {
                rows[rows.count - 1].items.append((index, x, size))
                rows[rows.count - 1].width = x + size.width
                rows[rows.count - 1].height = max(row.height, size.height)
            }
        }
        return rows.filter { !$0.items.isEmpty }
    }
}
