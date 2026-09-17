import Foundation

/// Reads and writes the daily Markdown files. The format is documented in the README so any
/// tool (AI assistants, scripts, review templates) can consume it.
public enum CaptureFormatter {
    public static let entryPrefix = "### "
    static let questionPrefix = "> Q: "
    static let separator = " · "

    public static func fileName(for date: Date, calendar: Calendar) -> String {
        "\(dayString(for: date, calendar: calendar)).md"
    }

    public static func fileHeader(for date: Date, calendar: Calendar) -> String {
        let weekday = formatter("EEEE", calendar: calendar).string(from: date)
        return """
        # Impact captures — \(dayString(for: date, calendar: calendar)) (\(weekday))

        Self-reported notes captured in the moment. Unverified: treat them as memory joggers and \
        corroborate with Slack, Jira, Confluence, GitHub or calendar evidence where possible.

        """
    }

    public static func entry(for capture: Capture, calendar: Calendar) -> String {
        var headerParts = [
            formatter("HH:mm", calendar: calendar).string(from: capture.date),
            capture.source.rawValue,
        ]
        if let trigger = capture.trigger {
            headerParts.append(trigger)
        }
        headerParts.append(capture.inputMethod.rawValue)
        if let categoryID = capture.categoryID {
            headerParts.append("#\(categoryID)")
        }

        var lines = ["", entryPrefix + headerParts.joined(separator: separator), ""]
        if let question = capture.question {
            lines += [questionPrefix + question, ""]
        }
        lines.append(capture.text.trimmingCharacters(in: .whitespacesAndNewlines))
        return lines.joined(separator: "\n") + "\n"
    }

    public static func document(for captures: [Capture], day: Date, calendar: Calendar) -> String {
        fileHeader(for: day, calendar: calendar) + captures.map { entry(for: $0, calendar: calendar) }.joined()
    }

    /// Parses a daily file. Lines before the first entry (the header) are ignored.
    public static func parse(_ content: String, day: Date, calendar: Calendar) -> [Capture] {
        var captures: [Capture] = []
        var header: String?
        var body: [String] = []

        func flush() {
            guard let header, var capture = parseHeader(header, day: day, calendar: calendar) else { return }
            var lines = body
            while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.removeFirst()
            }
            if let first = lines.first, first.hasPrefix(questionPrefix) {
                capture.question = String(first.dropFirst(questionPrefix.count))
                lines.removeFirst()
            }
            capture.text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            captures.append(capture)
        }

        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix(entryPrefix) {
                flush()
                header = String(line.dropFirst(entryPrefix.count))
                body = []
            } else if header != nil {
                body.append(line)
            }
        }
        flush()
        return captures
    }

    private static func parseHeader(_ header: String, day: Date, calendar: Calendar) -> Capture? {
        let parts = header.components(separatedBy: separator).map { $0.trimmingCharacters(in: .whitespaces) }
        let time = parts.first?.split(separator: ":").compactMap { Int($0) } ?? []
        guard
            time.count == 2,
            let date = calendar.date(bySettingHour: time[0], minute: time[1], second: 0, of: day)
        else { return nil }

        var capture = Capture(date: date, source: .menu, text: "", inputMethod: .typed)
        for part in parts.dropFirst() {
            if let source = CaptureSource(rawValue: part) {
                capture.source = source
            } else if let method = InputMethod(rawValue: part) {
                capture.inputMethod = method
            } else if part.hasPrefix("#") {
                capture.categoryID = String(part.dropFirst())
            } else if !part.isEmpty {
                capture.trigger = part
            }
        }
        return capture
    }

    static func dayString(for date: Date, calendar: Calendar) -> String {
        formatter("yyyy-MM-dd", calendar: calendar).string(from: date)
    }

    static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
}
