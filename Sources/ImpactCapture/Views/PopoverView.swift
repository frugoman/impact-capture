import ImpactCaptureCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var transcriber: SpeechTranscriber
    let close: () -> Void

    @State private var draft = ""
    @State private var draftCategory: String?
    @State private var usedVoice = false
    @State private var scope = Scope.today
    @State private var justLogged = false

    enum Scope: String, CaseIterable {
        case today = "Today"
        case week = "This week"
    }

    init(model: AppModel, close: @escaping () -> Void) {
        self.model = model
        transcriber = model.transcriber
        self.close = close
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            quickLog
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            Rectangle().fill(Brand.hairline).frame(height: 1)

            timeline

            Rectangle().fill(Brand.hairline).frame(height: 1)

            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 400, height: 580)
        .background(Brand.background)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            Wordmark()
            Spacer()
            HStack(spacing: 14) {
                StatView(value: model.stats.today, label: "today")
                StatView(value: model.stats.thisWeek, label: "week")
                StatView(value: model.stats.streak, label: "streak", highlight: model.stats.streak >= 3)
            }
        }
    }

    // MARK: Quick log

    private var quickLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            CaptureEditor(
                text: $draft,
                categoryID: $draftCategory,
                categories: model.settings.categories,
                transcriber: transcriber,
                placeholder: "Had a chat that mattered? Unblocked someone? Log it.",
                height: 64,
                onToggleMic: toggleMic
            )

            HStack(spacing: 6) {
                if justLogged {
                    Label("Logged", systemImage: "checkmark")
                        .font(Brand.mono(11, .medium))
                        .foregroundStyle(Brand.success)
                        .transition(.opacity)
                } else if let shortcut = model.settings.typingShortcut {
                    KeyCap(text: shortcut.displayString)
                    Text("from anywhere")
                        .font(Brand.mono(10))
                        .foregroundStyle(Brand.tertiaryText)
                }
                Spacer()
                Button("Log it", action: logDraft)
                    .buttonStyle(SparkButtonStyle(compact: true))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!transcriber.isRecording && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func toggleMic() {
        if transcriber.isRecording {
            transcriber.stop()
            return
        }
        usedVoice = true
        let prefix = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        transcriber.start { transcript in
            draft = prefix.isEmpty ? transcript : "\(prefix) \(transcript)"
        }
    }

    private func logDraft() {
        transcriber.stop {
            let saved = model.log(
                text: draft,
                categoryID: draftCategory,
                inputMethod: usedVoice ? .voice : .typed,
                source: .menu
            )
            guard saved else { return }
            draft = ""
            draftCategory = nil
            usedVoice = false
            scope = .today
            withAnimation { justLogged = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { justLogged = false }
            }
        }
    }

    // MARK: Timeline

    private var timeline: some View {
        VStack(spacing: 0) {
            HStack {
                SegmentedTabs(selection: $scope)
                Spacer()
                if model.isPaused, let until = model.pausedUntil {
                    Label("Paused until \(until.formatted(pauseFormat(until)))", systemImage: "moon.zzz")
                        .font(Brand.mono(10.5))
                        .foregroundStyle(Brand.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            let entries = (scope == .today ? model.today : model.week).reversed()
            if entries.isEmpty {
                EmptyTimeline(scope: scope, askNow: model.askNow)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedByDay(Array(entries)), id: \.day) { group in
                            if scope == .week {
                                Text(group.day.formatted(.dateTime.weekday(.wide).day().month()))
                                    .font(Brand.mono(10.5, .medium))
                                    .foregroundStyle(Brand.tertiaryText)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                            }
                            ForEach(group.items) { stored in
                                CaptureRow(model: model, stored: stored)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func pauseFormat(_ date: Date) -> Date.FormatStyle {
        Calendar.current.isDateInToday(date) ? .dateTime.hour().minute() : .dateTime.weekday().hour().minute()
    }

    private func groupedByDay(_ items: [StoredCapture]) -> [(day: Date, items: [StoredCapture])] {
        var groups: [(day: Date, items: [StoredCapture])] = []
        for item in items {
            if let last = groups.last, last.day == item.day {
                groups[groups.count - 1].items.append(item)
            } else {
                groups.append((item.day, [item]))
            }
        }
        return groups
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 2) {
            FooterButton(title: "Check in", systemImage: "sparkles") {
                close()
                model.askNow()
            }
            FooterButton(title: "Export", systemImage: "square.and.arrow.up") {
                close()
                model.showExport()
            }
            Spacer()
            Menu {
                if model.isPaused {
                    Button("Resume check-ins", action: model.resume)
                } else {
                    Button("Pause for an hour", action: model.pauseForAnHour)
                    Button("Pause until next workday", action: model.pauseUntilNextWorkday)
                }
                Divider()
                Button("Open captures folder", action: model.revealCapturesFolder)
                Button("Settings…") {
                    close()
                    model.showSettings()
                }
                Divider()
                Button("Quit Impact Capture") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Brand.secondaryText)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            IconButton(systemImage: "gearshape", help: "Settings") {
                close()
                model.showSettings()
            }
        }
    }
}

private struct StatView: View {
    let value: Int
    let label: String
    var highlight = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(value)")
                .font(Brand.mono(16, .semibold))
                .foregroundStyle(highlight ? Brand.spark : Brand.text)
                .contentTransition(.numericText())
            Text(label)
                .font(Brand.mono(9.5))
                .foregroundStyle(Brand.tertiaryText)
        }
        .animation(.snappy, value: value)
    }
}

private struct SegmentedTabs: View {
    @Binding var selection: PopoverView.Scope
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PopoverView.Scope.allCases, id: \.self) { scope in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = scope }
                } label: {
                    Text(scope.rawValue)
                        .font(.system(size: 12, weight: selection == scope ? .semibold : .regular))
                        .foregroundStyle(selection == scope ? Brand.text : Brand.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background {
                            if selection == scope {
                                Capsule()
                                    .fill(Brand.surface)
                                    .overlay(Capsule().stroke(Brand.hairline))
                                    .matchedGeometryEffect(id: "tab", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Brand.raised.opacity(0.6)))
    }
}

private struct EmptyTimeline: View {
    let scope: PopoverView.Scope
    let askNow: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(scope == .today ? "$ git log --today" : "$ git log --this-week")
                .font(Brand.mono(11))
                .foregroundStyle(Brand.tertiaryText)
            Text("Nothing logged yet.")
                .font(Brand.display(15))
                .foregroundStyle(Brand.text)
            Text("That hallway chat, the review that changed a design,\nthe teammate you unblocked: they all count.")
                .font(.system(size: 12))
                .foregroundStyle(Brand.secondaryText)
                .multilineTextAlignment(.center)
            Button("Ask me something", action: askNow)
                .buttonStyle(QuietButtonStyle(compact: true))
                .padding(.top, 4)
        }
        .padding(24)
    }
}

private struct FooterButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? Brand.text : Brand.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(isHovered ? Brand.raised : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct CaptureRow: View {
    @ObservedObject var model: AppModel
    let stored: StoredCapture

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editText = ""
    @State private var editCategory: String?
    @State private var confirmDelete = false

    private var capture: Capture { stored.capture }
    private var category: CaptureCategory? { model.category(for: capture.categoryID) }
    private var accent: Color { category.map { Brand.color($0.color) } ?? Brand.hairline }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text(capture.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                    .font(Brand.mono(11, .medium))
                    .foregroundStyle(Brand.secondaryText)
                Image(systemName: capture.inputMethod == .voice ? "waveform" : "keyboard")
                    .font(.system(size: 9))
                    .foregroundStyle(Brand.tertiaryText)
            }
            .frame(width: 38, alignment: .leading)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(accent)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                if isEditing {
                    editor
                } else {
                    content
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(isHovered && !isEditing ? Brand.raised.opacity(0.45) : .clear)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Edit", action: beginEdit)
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(capture.text, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) { confirmDelete = true }
        }
        .confirmationDialog("Delete this capture?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { model.delete(stored) }
        } message: {
            Text("It will be removed from the Markdown file too.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let question = capture.question {
            Text(question)
                .font(.system(size: 11))
                .foregroundStyle(Brand.tertiaryText)
                .lineLimit(1)
        }
        Text(capture.text)
            .font(.system(size: 13))
            .foregroundStyle(Brand.text)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
        HStack(spacing: 6) {
            if let category {
                Text(category.name)
                    .font(Brand.mono(10, .medium))
                    .foregroundStyle(Brand.color(category.color))
            }
            Spacer()
            if isHovered {
                IconButton(systemImage: "pencil", help: "Edit", action: beginEdit)
                IconButton(systemImage: "trash", help: "Delete") { confirmDelete = true }
            }
        }
        .frame(height: 18)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $editText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(4)
                .frame(height: 70)
                .background(RoundedRectangle(cornerRadius: 8).fill(Brand.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.spark))
            CategoryPicker(categories: model.settings.categories, selection: $editCategory)
            HStack {
                Spacer()
                Button("Cancel") { isEditing = false }
                    .buttonStyle(QuietButtonStyle(compact: true))
                Button("Save") {
                    model.update(stored, text: editText, categoryID: editCategory)
                    isEditing = false
                }
                .buttonStyle(SparkButtonStyle(compact: true))
                .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func beginEdit() {
        editText = capture.text
        editCategory = capture.categoryID
        isEditing = true
    }
}
