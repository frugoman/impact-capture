import ImpactCaptureCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var section: Section

    init(model: AppModel, initialSection: Section = .general) {
        self.model = model
        _section = State(initialValue: initialSection)
    }

    enum Section: String, CaseIterable, Identifiable {
        case general = "General"
        case checkIns = "Check-ins"
        case categories = "Categories"
        case questions = "Questions"
        case shortcuts = "Shortcuts"
        case integrations = "Integrations"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .checkIns: return "bell.badge"
            case .categories: return "tag"
            case .questions: return "text.bubble"
            case .shortcuts: return "command"
            case .integrations: return "puzzlepiece.extension"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Brand.hairline).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(section.rawValue)
                        .font(Brand.display(22, .bold))
                        .foregroundStyle(Brand.text)
                        .padding(.bottom, 20)
                    content
                }
                .padding(.horizontal, 32)
                .padding(.top, 40)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 780, height: 580)
        .background(Brand.background)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Wordmark(showsTagline: false)
                .padding(.horizontal, 10)
                .padding(.top, 40)
                .padding(.bottom, 20)
            ForEach(Section.allCases) { item in
                Button {
                    section = item
                } label: {
                    Label(item.rawValue, systemImage: item.systemImage)
                        .font(.system(size: 13, weight: section == item ? .semibold : .regular))
                        .foregroundStyle(section == item ? Brand.text : Brand.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(section == item ? Brand.raised : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                .font(Brand.mono(10))
                .foregroundStyle(Brand.tertiaryText)
                .padding(10)
        }
        .padding(.horizontal, 10)
        .frame(width: 210)
        .background(Brand.surface.opacity(0.5))
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .general: GeneralSettings(model: model)
        case .checkIns: CheckInControls(settings: $model.settings)
        case .categories: CategorySettings(categories: $model.settings.categories)
        case .questions: QuestionSettings(settings: $model.settings)
        case .shortcuts: ShortcutSettings(model: model)
        case .integrations: IntegrationSettings(model: model)
        }
    }
}

private struct GeneralSettings: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("captures folder").padding(.bottom, 8)
            FolderField(path: model.settings.capturesFolderPath, choose: model.chooseCapturesFolder, reveal: model.revealCapturesFolder)
            Text("One Markdown file per day. Existing files in the old folder aren't moved.")
                .font(.system(size: 11.5))
                .foregroundStyle(Brand.secondaryText)
                .padding(.top, 6)
                .padding(.bottom, 20)

            SettingRow(title: "Open at login", detail: "Keeps check-ins and shortcuts working without you thinking about it.") {
                Toggle("", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Brand.spark)
            }
            RowDivider()
            SettingRow(title: "Speech language", detail: "The language you talk in. Transcription runs on this Mac.") {
                Picker("", selection: $model.settings.speechLocaleIdentifier) {
                    ForEach(SpeechTranscriber.supportedLocales, id: \.identifier) { locale in
                        Text(SpeechTranscriber.displayName(for: locale)).tag(locale.identifier)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
            }
            RowDivider()
            SettingRow(title: "Microphone & speech", detail: "Only used while you choose to talk.") {
                PermissionRow()
            }
            RowDivider()
            SettingRow(title: "Setup", detail: "Walk through the first-run setup again.") {
                Button("Run setup") { model.showOnboarding() }
                    .buttonStyle(QuietButtonStyle(compact: true))
            }
        }
    }
}

private struct CategorySettings: View {
    @Binding var categories: [CaptureCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tag captures so patterns show up at review time. Rename freely: the #tag written to your files stays the same so old entries still match.")
                .font(.system(size: 12.5))
                .foregroundStyle(Brand.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach($categories) { $category in
                    HStack(spacing: 10) {
                        Menu {
                            ForEach(CategoryColor.allCases) { color in
                                Button(color.rawValue.capitalized) { category.color = color }
                            }
                        } label: {
                            Circle().fill(Brand.color(category.color)).frame(width: 14, height: 14)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()

                        TextField("Name", text: $category.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Brand.text)

                        Text("#\(category.id)")
                            .font(Brand.mono(11))
                            .foregroundStyle(Brand.tertiaryText)

                        IconButton(systemImage: "trash", help: "Delete category") {
                            categories.removeAll { $0.id == category.id }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    if category.id != categories.last?.id {
                        RowDivider()
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Brand.hairline))

            HStack {
                Button {
                    let name = "New category"
                    let id = CaptureCategory.makeID(from: name, existing: categories.map(\.id))
                    let color = CategoryColor.allCases[categories.count % CategoryColor.allCases.count]
                    categories.append(CaptureCategory(id: id, name: name, color: color))
                } label: {
                    Label("Add category", systemImage: "plus")
                }
                .buttonStyle(QuietButtonStyle(compact: true))
                Spacer()
                Button("Restore defaults") { categories = CaptureCategory.defaults }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.secondaryText)
            }
        }
    }
}

private struct QuestionSettings: View {
    @Binding var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Questions rotate so they don't get stale. Keep them about the invisible stuff: conversations, help, influence, the things no tool records.")
                .font(.system(size: 12.5))
                .foregroundStyle(Brand.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            group(.awayReturn, title: "after time away", hint: "{minutes} becomes how long you were away.")
            group(.reflective, title: "end of day & on demand", hint: nil)

            HStack {
                Spacer()
                Button("Restore default questions") { settings.questions = PromptQuestion.defaults }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.secondaryText)
            }
        }
    }

    private func group(_ kind: QuestionKind, title: String, hint: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title)
                if let hint {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(Brand.tertiaryText)
                }
                Spacer()
                Button {
                    settings.questions.append(PromptQuestion(kind: kind, text: "", followUp: "What happened?"))
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(QuietButtonStyle(compact: true))
            }

            ForEach($settings.questions) { $question in
                if question.kind == kind {
                    QuestionEditor(question: $question, categories: settings.categories) {
                        settings.questions.removeAll { $0.id == question.id }
                    }
                }
            }
        }
    }
}

private struct QuestionEditor: View {
    @Binding var question: PromptQuestion
    let categories: [CaptureCategory]
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $question.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Brand.spark)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Question", text: $question.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Brand.text)
                HStack(spacing: 6) {
                    Text("then:")
                        .font(Brand.mono(11))
                        .foregroundStyle(Brand.tertiaryText)
                    TextField("Follow-up", text: $question.followUp)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Brand.secondaryText)
                }
            }
            .opacity(question.isEnabled ? 1 : 0.5)

            Picker("", selection: $question.categoryID) {
                Text("No category").tag(String?.none)
                ForEach(categories) { category in
                    Text(category.name).tag(String?.some(category.id))
                }
            }
            .labelsHidden()
            .frame(width: 130)

            IconButton(systemImage: "trash", help: "Delete question", action: delete)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.surface))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Brand.hairline))
    }
}

private struct ShortcutSettings: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Global shortcuts work from any app. Pick combos other apps don't use, like ⌃⌥ plus a letter.")
                .font(.system(size: 12.5))
                .foregroundStyle(Brand.secondaryText)
                .padding(.bottom, 12)

            SettingRow(title: "Log by typing", detail: "Opens the quick-log box on every screen.") {
                ShortcutRecorder(shortcut: $model.settings.typingShortcut, onRecordingChange: model.setHotKeysSuspended)
            }
            RowDivider()
            SettingRow(title: "Log by voice", detail: "Same box, already listening.") {
                ShortcutRecorder(shortcut: $model.settings.voiceShortcut, onRecordingChange: model.setHotKeysSuspended)
            }

            if !model.unavailableShortcuts.isEmpty {
                Label(
                    "\(model.unavailableShortcuts.joined(separator: ", ")) is already used by another app. Pick a different combo.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 12))
                .foregroundStyle(Brand.danger)
                .padding(.top, 12)
            }
        }
    }
}

private struct IntegrationSettings: View {
    @ObservedObject var model: AppModel
    @State private var copied: String?

    static let aiPrompt = """
    The folder below contains my Impact Capture log: one Markdown file per day (YYYY-MM-DD.md). \
    Each entry starts with a header like "### 10:42 · prompt · away-return · voice · #collaboration" \
    (time, how it was captured, optional trigger, typed or voice, optional #category), an optional \
    "> Q:" line with the question I answered, then my note. Notes are self-reported and often cover \
    work that leaves no written trace (conversations, unblocking, influence, mentoring, early risk \
    spotting). Voice notes may contain transcription errors.

    Read the files for the period I give you and produce performance evidence: group related notes \
    into themes, describe what I did and the observable outcome, keep people and team names, flag \
    notes that other evidence (Slack, tickets, docs, PRs) could corroborate, and don't invent \
    outcomes that aren't in the notes.
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("use with any ai tool")
                    Text("Your log is plain Markdown. Give this prompt and your captures folder to Claude, ChatGPT, Codex or anything else to turn notes into review evidence.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Brand.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button(copied == "prompt" ? "Copied" : "Copy AI prompt") { copy(Self.aiPrompt, id: "prompt") }
                            .buttonStyle(SparkButtonStyle(compact: true))
                        Button("Open folder", action: model.revealCapturesFolder)
                            .buttonStyle(QuietButtonStyle(compact: true))
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("url scheme")
                    Text("Launchers like Raycast or Alfred, Shortcuts and scripts can log through these URLs.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Brand.secondaryText)
                    urlRow("impactcapture://log?text=Paired%20with%20Ana&category=unblocking", "Log silently")
                    urlRow("impactcapture://compose", "Open the quick-log box")
                    urlRow("impactcapture://voice", "Open it already listening")
                    urlRow("impactcapture://ask", "Ask a check-in question now")
                    Text("Category ids: " + model.settings.categories.map(\.id).joined(separator: ", "))
                        .font(Brand.mono(10.5))
                        .foregroundStyle(Brand.tertiaryText)
                }
            }
        }
    }

    private func urlRow(_ url: String, _ description: String) -> some View {
        HStack {
            Text(url)
                .font(Brand.mono(11))
                .foregroundStyle(Brand.text)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(description)
                .font(.system(size: 11.5))
                .foregroundStyle(Brand.secondaryText)
            IconButton(systemImage: copied == url ? "checkmark" : "doc.on.doc", help: "Copy") { copy(url, id: url) }
        }
    }

    private func copy(_ text: String, id: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copied == id { copied = nil }
        }
    }
}
