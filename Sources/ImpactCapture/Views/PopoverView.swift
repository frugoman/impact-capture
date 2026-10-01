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
        .background(PaperBackground())
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    LogoMark(size: 22)
                    Text("Impact Capture")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Brand.secondaryText)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(model.stats.today)")
                        .font(Brand.display(30, .bold))
                        .foregroundStyle(Brand.text)
                        .contentTransition(.numericText())
                        .animation(Brand.springy, value: model.stats.today)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(model.stats.today == 1 ? "capture today" : "captures today")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Brand.text)
                        Text("\(model.stats.thisWeek) this week")
                            .font(.system(size: 11))
                            .foregroundStyle(Brand.tertiaryText)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if model.stats.streak >= 2 {
                    Text("\(model.stats.streak)-day streak")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Brand.onHighlighter)
                        .highlighted(opacity: 1)
                }
                WeekStrip(captures: model.week)
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
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Brand.onHighlighter)
                        .highlighted(opacity: 1, animated: true)
                        .transition(.opacity)
                } else if let shortcut = model.settings.typingShortcut {
                    KeyCap(text: shortcut.displayString)
                    Text("logs from anywhere")
                        .font(.system(size: 11))
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
                                    .font(Brand.display(11, .semibold))
                                    .foregroundStyle(Brand.secondaryText)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                            }
                            ForEach(group.items) { stored in
                                CaptureRow(model: model, stored: stored, isLast: stored.id == group.items.last?.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    .animation(Brand.springy, value: entries.map(\.id))
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

/// This week as seven small bars, today drawn in highlighter.
private struct WeekStrip: View {
    let captures: [StoredCapture]
    @State private var grown = Brand.isRenderingSnapshot

    private var days: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return (day, captures.filter { $0.day == day }.count)
        }
    }

    var body: some View {
        let days = days
        let peak = max(days.map(\.count).max() ?? 0, 3)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let isToday = Calendar.current.isDateInToday(day.date)
                let isFuture = day.date > Date()
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Brand.raised.opacity(isFuture ? 0.5 : 1)).frame(width: 7, height: 26)
                        Capsule()
                            .fill(isToday ? Brand.highlighter : Brand.text.opacity(0.72))
                            .overlay(Capsule().stroke(isToday ? Brand.onHighlighter.opacity(0.25) : .clear))
                            .frame(width: 7, height: day.count == 0 ? 0 : max(6, 26 * CGFloat(day.count) / CGFloat(peak)))
                            .scaleEffect(y: grown ? 1 : 0, anchor: .bottom)
                            .animation(Brand.springy.delay(Double(index) * 0.035), value: grown)
                    }
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 9, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Brand.text : Brand.tertiaryText)
                }
                .help("\(day.date.formatted(.dateTime.weekday(.wide))): \(day.count) \(day.count == 1 ? "capture" : "captures")")
            }
        }
        .onAppear { grown = true }
    }
}

/// A dotted stand-in for the timeline when there's nothing on it yet.
private struct EmptySpine: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3) { index in
                Circle()
                    .strokeBorder(Brand.tertiaryText, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                    .frame(width: 12, height: 12)
                if index < 2 {
                    Rectangle().fill(Brand.hairline).frame(width: 28, height: 1.5)
                }
            }
        }
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
                        .foregroundStyle(selection == scope ? Brand.onHighlighter : Brand.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background {
                            if selection == scope {
                                HighlightShape()
                                    .fill(Brand.highlighter)
                                    .matchedGeometryEffect(id: "tab", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
    }
}

private struct EmptyTimeline: View {
    let scope: PopoverView.Scope
    let askNow: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            EmptySpine()
                .padding(.bottom, 4)
            Text(scope == .today ? "Nothing logged today." : "Nothing logged this week.")
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
    var isLast = false

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editText = ""
    @State private var editCategory: String?
    @State private var confirmDelete = false

    private var capture: Capture { stored.capture }
    private var category: CaptureCategory? { model.category(for: capture.categoryID) }
    private var accent: Color { category.map { Brand.color($0.color) } ?? Brand.tertiaryText }

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

            // The spine: one node per capture, like a commit graph for the work git doesn't see.
            ZStack(alignment: .top) {
                Circle()
                    .fill(accent)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Brand.background, lineWidth: 2.5))
                    .scaleEffect(isHovered ? 1.25 : 1)
                    .animation(.snappy(duration: 0.18), value: isHovered)
                    .padding(.top, 3)
            }
            .frame(width: 12)
            .frame(maxHeight: .infinity, alignment: .top)

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
        .background(alignment: .topLeading) {
            // Time column (38) + spacing (12) + half the node column (6), inside the 16pt inset.
            Rectangle()
                .fill(Brand.hairline)
                .frame(width: 1.5)
                .frame(maxHeight: isLast ? 20 : .infinity, alignment: .top)
                .offset(x: 16 + 38 + 12 + 6 - 0.75)
        }
        .background(isHovered && !isEditing ? Brand.surface.opacity(0.7) : .clear)
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
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Brand.text)
                    .highlighted(Brand.color(category.color), opacity: 0.32)
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
