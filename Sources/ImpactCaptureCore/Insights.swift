import Foundation

public struct CaptureStats: Equatable {
    public var today: Int
    public var thisWeek: Int
    /// Consecutive workdays with at least one capture. Today doesn't break it until it has passed.
    public var streak: Int

    public init(today: Int = 0, thisWeek: Int = 0, streak: Int = 0) {
        self.today = today
        self.thisWeek = thisWeek
        self.streak = streak
    }
}

public enum StatsCalculator {
    public static func stats(
        captures: [StoredCapture],
        now: Date,
        workdays: Set<Int>,
        calendar: Calendar
    ) -> CaptureStats {
        var countsByDay: [Date: Int] = [:]
        for stored in captures {
            countsByDay[calendar.startOfDay(for: stored.day), default: 0] += 1
        }

        let today = calendar.startOfDay(for: now)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let thisWeek = countsByDay
            .filter { day, _ in week?.contains(day) ?? false }
            .map(\.value)
            .reduce(0, +)

        var streak = 0
        var day = today
        for offset in 0..<120 {
            let count = countsByDay[day] ?? 0
            let isWorkday = workdays.contains(calendar.component(.weekday, from: day))
            if count > 0 {
                streak += 1
            } else if isWorkday && offset > 0 {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return CaptureStats(today: countsByDay[today] ?? 0, thisWeek: thisWeek, streak: streak)
    }
}

public enum CaptureExporter {
    /// A review-ready Markdown summary of captures between two dates.
    public static func markdown(
        _ captures: [StoredCapture],
        categories: [CaptureCategory],
        from start: Date,
        through end: Date,
        calendar: Calendar
    ) -> String {
        let dayFormat = CaptureFormatter.formatter("EEEE d MMMM", calendar: calendar)
        let timeFormat = CaptureFormatter.formatter("HH:mm", calendar: calendar)
        let name: (String?) -> String? = { id in
            guard let id else { return nil }
            return categories.first { $0.id == id }?.name ?? id
        }

        var lines = [
            "# Impact log: \(CaptureFormatter.dayString(for: start, calendar: calendar)) to "
                + "\(CaptureFormatter.dayString(for: end, calendar: calendar))",
            "",
            "Self-reported notes captured in the moment with Impact Capture. They cover work that often "
                + "leaves no written trace. Corroborate with other evidence where possible.",
            "",
        ]

        guard !captures.isEmpty else {
            return (lines + ["_No captures in this period._", ""]).joined(separator: "\n")
        }

        var counts: [String: Int] = [:]
        var uncategorised = 0
        for stored in captures {
            if let category = name(stored.capture.categoryID) {
                counts[category, default: 0] += 1
            } else {
                uncategorised += 1
            }
        }
        var breakdown = counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { "\($0.key) \($0.value)" }
        if uncategorised > 0 {
            breakdown.append("Uncategorised \(uncategorised)")
        }
        lines += ["**\(captures.count) captures** · " + breakdown.joined(separator: " · "), ""]

        let byDay = Dictionary(grouping: captures) { calendar.startOfDay(for: $0.day) }
        for day in byDay.keys.sorted() {
            lines += ["## \(dayFormat.string(from: day))", ""]
            for stored in byDay[day] ?? [] {
                let capture = stored.capture
                var line = "- **\(timeFormat.string(from: capture.date))**"
                if let category = name(capture.categoryID) {
                    line += " · _\(category)_"
                }
                line += " · " + capture.text.replacingOccurrences(of: "\n", with: " ")
                lines.append(line)
                if let question = capture.question {
                    lines.append("  - Prompted by: \"\(question)\"")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
