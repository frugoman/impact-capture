import ImpactCaptureCore
import SwiftUI

struct ExportView: View {
    @ObservedObject var model: AppModel

    @State private var start = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()
    @State private var end = Date()
    @State private var copied = false

    private enum Preset: String, CaseIterable, Identifiable {
        case week = "This week"
        case twoWeeks = "Last 2 weeks"
        case month = "Last 30 days"
        case quarter = "Last 90 days"
        case half = "This half"

        var id: String { rawValue }

        func range(now: Date, calendar: Calendar) -> (Date, Date) {
            switch self {
            case .week:
                return (calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now, now)
            case .twoWeeks:
                return (calendar.date(byAdding: .day, value: -13, to: now) ?? now, now)
            case .month:
                return (calendar.date(byAdding: .day, value: -29, to: now) ?? now, now)
            case .quarter:
                return (calendar.date(byAdding: .day, value: -89, to: now) ?? now, now)
            case .half:
                let month = calendar.component(.month, from: now)
                let components = DateComponents(year: calendar.component(.year, from: now), month: month <= 6 ? 1 : 7, day: 1)
                return (calendar.date(from: components) ?? now, now)
            }
        }
    }

    private var markdown: String {
        model.exportMarkdown(from: start, through: end)
    }

    private var count: Int {
        model.captures(from: start, through: end).count
    }

    var body: some View {
        HStack(spacing: 0) {
            controls
                .frame(width: 280)
                .padding(.horizontal, 24)
                .padding(.top, 44)
                .padding(.bottom, 24)
            Rectangle().fill(Brand.hairline).frame(width: 1)
            preview
                .padding(.horizontal, 24)
                .padding(.top, 44)
                .padding(.bottom, 24)
        }
        .frame(width: 840, height: 580)
        .background(Brand.background)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Export")
                .font(Brand.display(22, .bold))
                .foregroundStyle(Brand.text)
            Text("Review-ready Markdown for your performance doc, a 1:1, or an AI tool.")
                .font(.system(size: 12.5))
                .foregroundStyle(Brand.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 24)

            SectionLabel("period").padding(.bottom, 8)
            FlowLayout(spacing: 6) {
                ForEach(Preset.allCases) { preset in
                    let range = preset.range(now: Date(), calendar: .current)
                    CategoryChip(
                        name: preset.rawValue,
                        color: Brand.spark,
                        isSelected: Calendar.current.isDate(range.0, inSameDayAs: start) && Calendar.current.isDate(range.1, inSameDayAs: end)
                    ) {
                        start = range.0
                        end = range.1
                    }
                }
            }
            .padding(.bottom, 16)

            VStack(spacing: 8) {
                dateRow("From", $start)
                dateRow("To", $end)
            }
            .padding(.bottom, 24)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(count)")
                    .font(Brand.mono(28, .semibold))
                    .foregroundStyle(count > 0 ? Brand.spark : Brand.tertiaryText)
                Text(count == 1 ? "capture" : "captures")
                    .font(Brand.mono(12))
                    .foregroundStyle(Brand.secondaryText)
            }

            Spacer()

            VStack(spacing: 8) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(markdown, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy Markdown", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SparkButtonStyle())
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button {
                    let name = "impact-log-\(fileDate(start))-to-\(fileDate(end)).md"
                    model.save(markdown: markdown, suggestedName: name)
                } label: {
                    Label("Save as file…", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("preview")
            ScrollView {
                Text(markdown)
                    .font(Brand.mono(11.5))
                    .foregroundStyle(Brand.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Brand.hairline))
        }
    }

    private func dateRow(_ label: String, _ date: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(Brand.mono(11.5))
                .foregroundStyle(Brand.secondaryText)
            Spacer()
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
        }
    }

    private func fileDate(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}
