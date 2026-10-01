import AppKit
import Combine
import ImpactCaptureCore
import SwiftUI

/// Shows the same session centered on every screen so it isn't missed. All copies share one
/// `CaptureSession`, so typing in one mirrors to the others. The copy on the screen under the
/// mouse takes keyboard focus, without activating the app or stealing focus from the frontmost app.
@MainActor
final class CapturePanelController: NSObject {
    private var panels: [(panel: NSPanel, screen: NSScreen)] = []
    private var phaseObserver: AnyCancellable?

    var isVisible: Bool { panels.contains { $0.panel.isVisible } }

    func show(_ session: CaptureSession) {
        close()

        panels = NSScreen.screens.map { screen in
            (makePanel(for: session), screen)
        }
        fitToContent(animate: false)
        panels.forEach { $0.panel.orderFrontRegardless() }
        focus()

        phaseObserver = session.$phase
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.fitToContent(animate: true) }
    }

    func focus() {
        let mouse = NSEvent.mouseLocation
        let target = panels.first { NSMouseInRect(mouse, $0.screen.frame, false) } ?? panels.first
        target?.panel.orderFrontRegardless()
        target?.panel.makeKey()
    }

    func close() {
        phaseObserver = nil
        let closing = panels
        panels = []
        closing.forEach { $0.panel.close() }
    }

    private func makePanel(for session: CaptureSession) -> NSPanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 160),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: CaptureSessionView(session: session))
        return panel
    }

    private func fitToContent(animate: Bool) {
        for (panel, screen) in panels {
            guard let content = panel.contentView else { continue }
            content.layoutSubtreeIfNeeded()
            let size = content.fittingSize
            let visible = screen.visibleFrame
            let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2 + visible.height * 0.08)
            panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: animate)
            panel.invalidateShadow()
        }
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct CaptureSessionView: View {
    @ObservedObject var session: CaptureSession
    @ObservedObject private var transcriber: SpeechTranscriber

    init(session: CaptureSession) {
        self.session = session
        transcriber = session.transcriber
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                LogoMark(size: 20)
                Text(session.question == nil ? "Quick log" : "Check-in")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Brand.onHighlighter)
                    .highlighted(opacity: 1, animated: true)
                Spacer()
                if session.phase == .asking {
                    KeyCap(text: "esc")
                    Text("skips")
                        .font(.system(size: 11))
                        .foregroundStyle(Brand.tertiaryText)
                }
            }

            Text(session.prompt)
                .font(Brand.display(19, .semibold))
                .lineSpacing(2)
                .foregroundStyle(Brand.text)
                .fixedSize(horizontal: false, vertical: true)

            switch session.phase {
            case .asking: askingControls
            case .answering: answeringControls
            }
        }
        .padding(22)
        .frame(width: 460)
        .background(
            PaperBackground()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Brand.hairline)
        )
        .overlay(alignment: .leading) {
            // A margin rule, like the red line on notebook paper, in highlighter.
            Capsule()
                .fill(Brand.highlighter)
                .frame(width: 3)
                .padding(.vertical, 22)
                .padding(.leading, 1)
        }
    }

    private var askingControls: some View {
        HStack(spacing: 8) {
            Button("Not now") { session.notNow() }
                .buttonStyle(QuietButtonStyle())
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("No") { session.answerNo() }
                .buttonStyle(QuietButtonStyle())
            Button("Yes, log it") { session.answerYes() }
                .buttonStyle(SparkButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
    }

    private var answeringControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            CaptureEditor(
                text: $session.text,
                categoryID: $session.categoryID,
                categories: session.categories,
                transcriber: transcriber,
                placeholder: "Talk or type. A sentence is plenty.",
                height: 92,
                onToggleMic: session.toggleRecording
            )

            HStack(spacing: 8) {
                KeyCap(text: "⌘↩")
                Text("logs")
                    .font(.system(size: 11))
                    .foregroundStyle(Brand.tertiaryText)
                Spacer()
                Button("Cancel") { session.cancel() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Log it") { session.save() }
                    .buttonStyle(SparkButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!session.canSave)
            }
        }
    }
}
