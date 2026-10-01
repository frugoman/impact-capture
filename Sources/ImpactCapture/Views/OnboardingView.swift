import ImpactCaptureCore
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var step: Int

    init(model: AppModel, initialStep: Int = 0) {
        self.model = model
        _step = State(initialValue: initialStep)
    }

    private let stepCount = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            progress
                .padding(.bottom, 28)

            Group {
                switch step {
                case 0: welcome
                case 1: folder
                case 2: checkIns
                default: ready
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(step)

            footer
        }
        .padding(.horizontal, 40)
        .padding(.top, 44)
        .padding(.bottom, 28)
        .frame(width: 640, height: 640)
        .background(PaperBackground())
    }

    // MARK: Chrome

    private var progress: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Brand.highlighter : index < step ? Brand.text.opacity(0.7) : Brand.hairline)
                        .frame(width: index == step ? 28 : 12, height: 5)
                }
            }
            Spacer()
            Text("Step \(step + 1) of \(stepCount)")
                .font(.system(size: 11.5))
                .foregroundStyle(Brand.tertiaryText)
        }
        .animation(.snappy, value: step)
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { go(to: step - 1) }
                    .buttonStyle(QuietButtonStyle())
            }
            Spacer()
            if step < stepCount - 1 {
                Button(step == 0 ? "Get started" : "Continue") { go(to: step + 1) }
                    .buttonStyle(SparkButtonStyle())
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Start capturing") { model.finishOnboarding() }
                    .buttonStyle(SparkButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func go(to newStep: Int) {
        withAnimation(.snappy(duration: 0.28)) { step = newStep }
    }

    private func title(_ text: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(Brand.display(25, .bold))
                .lineSpacing(1)
                .foregroundStyle(Brand.text)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Brand.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 24)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoMark(size: 64)
                .padding(.bottom, 24)
            title(
                "Capture the work that\nnever makes it into a commit.",
                "The coffee chat that unblocked a team. The review comment that changed a design. The risk you called early. Real impact, and gone from memory by review season."
            )
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    systemImage: "bubble.left.and.text.bubble.right",
                    title: "Tiny check-ins at natural breaks",
                    detail: "When you come back to your Mac or wrap up the day. Never mid-flow, and easy to skip."
                )
                FeatureRow(
                    systemImage: "waveform",
                    title: "Talk or type in seconds",
                    detail: "Speech is transcribed on this Mac. Nothing is sent anywhere."
                )
                FeatureRow(
                    systemImage: "doc.text",
                    title: "Plain Markdown you own",
                    detail: "One file per day. Paste it into your review, or point any AI tool at the folder."
                )
            }
        }
    }

    private var folder: some View {
        VStack(alignment: .leading, spacing: 0) {
            title(
                "Where should your log live?",
                "Pick any folder. Somewhere synced or backed up is a good idea. You can change it later."
            )
            FolderField(
                path: model.settings.capturesFolderPath,
                choose: model.chooseCapturesFolder,
                reveal: model.revealCapturesFolder
            )
            .padding(.bottom, 24)

            SectionLabel("what a day looks like")
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 6) {
                Text("2026-09-17.md")
                    .foregroundStyle(Brand.tertiaryText)
                Text("### 10:42 · prompt · away-return · voice · #collaboration")
                    .foregroundStyle(Brand.text)
                    .highlighted(opacity: 0.55)
                Text("> Q: You were away 25 min. Did you talk to anyone about work?")
                    .foregroundStyle(Brand.secondaryText)
                Text("Coffee with Marco from Payments. We agreed to split the\nmigration into two PRs so they can ship their part first.")
                    .foregroundStyle(Brand.text)
            }
            .font(Brand.mono(11.5))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.surface))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Brand.hairline))
        }
    }

    private var checkIns: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                title(
                    "When can we check in?",
                    "Check-ins show up in the middle of every screen, so pick a pace you'll actually answer."
                )
                CheckInControls(settings: $model.settings)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: 0) {
            title(
                "Last thing: make it effortless.",
                "Log from anywhere with a shortcut, and let it start with your Mac so you never have to remember it."
            )
            VStack(spacing: 0) {
                SettingRow(title: "Log by typing", detail: "Opens a quick-log box on every screen.") {
                    ShortcutRecorder(shortcut: $model.settings.typingShortcut, onRecordingChange: model.setHotKeysSuspended)
                }
                RowDivider()
                SettingRow(title: "Log by voice", detail: "Same box, already listening.") {
                    ShortcutRecorder(shortcut: $model.settings.voiceShortcut, onRecordingChange: model.setHotKeysSuspended)
                }
                RowDivider()
                SettingRow(title: "Microphone & speech", detail: "Only used while you choose to talk.") {
                    PermissionRow()
                }
                RowDivider()
                SettingRow(title: "Open at login", detail: "Recommended. The whole point is not having to remember.") {
                    Toggle("", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Brand.spark)
                }
            }
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Brand.hairline))

            if let shortcut = model.settings.typingShortcut {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").foregroundStyle(Brand.spark)
                    Text("Try it now: press")
                    KeyCap(text: shortcut.displayString)
                    Text("and log your first win.")
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Brand.secondaryText)
                .padding(.top, 18)
            }
        }
    }
}

private struct FeatureRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Brand.onHighlighter)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Brand.highlighter))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Brand.text)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Brand.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
