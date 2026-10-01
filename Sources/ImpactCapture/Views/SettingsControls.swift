import ImpactCaptureCore
import SwiftUI

/// A labelled row used by Settings and setup.
struct SettingRow<Content: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Brand.text)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Brand.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 220, alignment: .leading)
            Spacer(minLength: 0)
            content
        }
        .padding(.vertical, 10)
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Brand.hairline).frame(height: 1)
    }
}

struct FrequencyPicker: View {
    @Binding var frequency: PromptFrequency

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(PromptFrequency.allCases) { option in
                Button {
                    frequency = option
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(option.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Brand.text)
                            Spacer()
                            Image(systemName: frequency == option ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(frequency == option ? Brand.spark : Brand.tertiaryText)
                        }
                        Text(option.detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Brand.secondaryText)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(frequency == option ? Brand.highlighter.opacity(0.18) : Brand.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(frequency == option ? Brand.text.opacity(0.7) : Brand.hairline, lineWidth: frequency == option ? 1.5 : 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WorkdayPicker: View {
    @Binding var workdays: Set<Int>

    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                let isOn = workdays.contains(weekday)
                Button {
                    if isOn {
                        workdays.remove(weekday)
                    } else {
                        workdays.insert(weekday)
                    }
                } label: {
                    Text(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(isOn ? Brand.onHighlighter : Brand.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(isOn ? Brand.highlighter : Brand.raised.opacity(0.7)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HourPicker: View {
    @Binding var hour: Int
    let range: ClosedRange<Int>

    var body: some View {
        Picker("", selection: $hour) {
            ForEach(Array(range), id: \.self) { value in
                Text(String(format: "%02d:00", value)).tag(value)
            }
        }
        .labelsHidden()
        .frame(width: 84)
    }
}

/// Every check-in option, shared between setup and Settings.
struct CheckInControls: View {
    @Binding var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FrequencyPicker(frequency: $settings.frequency)
                .padding(.bottom, 8)

            SettingRow(title: "Workdays", detail: "No check-ins on other days.") {
                WorkdayPicker(workdays: $settings.workdays)
            }
            RowDivider()
            SettingRow(title: "Working hours", detail: "Check-ins after time away only happen inside these hours.") {
                HStack(spacing: 6) {
                    HourPicker(hour: $settings.workdayStartHour, range: 5...12)
                    Text("to").foregroundStyle(Brand.secondaryText)
                    HourPicker(hour: $settings.workdayEndHour, range: 13...23)
                }
            }
            RowDivider()
            SettingRow(title: "When I come back to my Mac", detail: "After the screen was locked or idle. Most conversations happen away from the keyboard.") {
                HStack(spacing: 8) {
                    if settings.awayPromptsEnabled {
                        Stepper(value: $settings.minimumAwayMinutes, in: 5...90, step: 5) {
                            Text("after \(settings.minimumAwayMinutes) min")
                                .font(Brand.mono(12))
                                .foregroundStyle(Brand.text)
                        }
                    }
                    Toggle("", isOn: $settings.awayPromptsEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Brand.spark)
                }
            }
            RowDivider()
            SettingRow(title: "End-of-day reflection", detail: "One question to catch what the day hid. Skipped if you already logged plenty.") {
                HStack(spacing: 8) {
                    if settings.endOfDayEnabled {
                        DatePicker("", selection: endOfDayTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.field)
                            .frame(width: 80)
                    }
                    Toggle("", isOn: $settings.endOfDayEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Brand.spark)
                }
            }
        }
    }

    private var endOfDayTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: settings.endOfDayHour, minute: settings.endOfDayMinute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings.endOfDayHour = components.hour ?? 17
                settings.endOfDayMinute = components.minute ?? 30
            }
        )
    }
}

struct FolderField: View {
    let path: String
    let choose: () -> Void
    let reveal: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 16))
                .foregroundStyle(Brand.spark)
            Text((path as NSString).abbreviatingWithTildeInPath)
                .font(Brand.mono(12))
                .foregroundStyle(Brand.text)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            IconButton(systemImage: "arrow.up.forward.square", help: "Show in Finder", action: reveal)
            Button("Change…", action: choose)
                .buttonStyle(QuietButtonStyle(compact: true))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.surface))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Brand.hairline))
    }
}

struct PermissionRow: View {
    @State private var state = SpeechTranscriber.permissionState

    var body: some View {
        HStack(spacing: 8) {
            switch state {
            case .granted:
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Brand.success)
            case .denied:
                Button("Open System Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                }
                .buttonStyle(QuietButtonStyle(compact: true))
            case .notDetermined:
                Button("Allow") {
                    Task {
                        _ = await SpeechTranscriber.requestPermissions()
                        state = SpeechTranscriber.permissionState
                    }
                }
                .buttonStyle(SparkButtonStyle(compact: true))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state = SpeechTranscriber.permissionState
        }
    }
}
