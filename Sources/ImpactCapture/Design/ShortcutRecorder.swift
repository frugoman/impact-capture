import AppKit
import Carbon.HIToolbox
import ImpactCaptureCore
import SwiftUI

extension ShortcutSpec {
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= Self.control }
        if flags.contains(.option) { modifiers |= Self.option }
        if flags.contains(.shift) { modifiers |= Self.shift }
        if flags.contains(.command) { modifiers |= Self.command }

        // Require a real modifier so a shortcut can't swallow normal typing.
        guard
            modifiers & (Self.command | Self.control | Self.option) != 0,
            Self.keyNames[UInt32(event.keyCode)] != nil
        else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    var displayString: String {
        var result = ""
        if modifiers & Self.control != 0 { result += "⌃" }
        if modifiers & Self.option != 0 { result += "⌥" }
        if modifiers & Self.shift != 0 { result += "⇧" }
        if modifiers & Self.command != 0 { result += "⌘" }
        return result + (Self.keyNames[keyCode] ?? "?")
    }

    static let keyNames: [UInt32: String] = {
        var names: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
            kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
            kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
            kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
            kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
            kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_Space: "Space", kVK_Return: "↩", kVK_ANSI_Period: ".", kVK_ANSI_Comma: ",",
            kVK_ANSI_Slash: "/", kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Minus: "-",
            kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
            kVK_ANSI_Backslash: "\\", kVK_ANSI_Grave: "`",
        ]
        for (index, key) in [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12].enumerated() {
            names[key] = "F\(index + 1)"
        }
        return Dictionary(uniqueKeysWithValues: names.map { (UInt32($0.key), $0.value) })
    }()
}

struct ShortcutRecorder: View {
    @Binding var shortcut: ShortcutSpec?
    /// Called with `true` while recording so the app can pause its global shortcuts.
    var onRecordingChange: (Bool) -> Void = { _ in }

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggle) {
                Text(isRecording ? "Press keys…" : (shortcut?.displayString ?? "Record"))
                    .font(Brand.mono(12, .medium))
                    .foregroundStyle(isRecording ? Brand.spark : (shortcut == nil ? Brand.tertiaryText : Brand.text))
                    .frame(minWidth: 96)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isRecording ? Brand.spark.opacity(0.12) : Brand.raised.opacity(0.7))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(isRecording ? Brand.spark : Brand.hairline)
                    )
            }
            .buttonStyle(.plain)

            if shortcut != nil && !isRecording {
                IconButton(systemImage: "xmark", help: "Clear shortcut") { shortcut = nil }
            }
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        isRecording = true
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
            } else if let spec = ShortcutSpec(event: event) {
                shortcut = spec
                stop()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isRecording {
            isRecording = false
            onRecordingChange(false)
        }
    }
}
