import Foundation

public enum CaptureStoreError: Error, Equatable {
    case emptyText
    case captureNotFound
}

/// Keeps one Markdown file per day in `directory`.
public final class CaptureStore {
    public let directory: URL
    private let calendar: Calendar
    private let fileManager: FileManager

    public init(directory: URL, calendar: Calendar = .current, fileManager: FileManager = .default) {
        self.directory = directory
        self.calendar = calendar
        self.fileManager = fileManager
    }

    public func fileURL(for date: Date) -> URL {
        directory.appendingPathComponent(CaptureFormatter.fileName(for: date, calendar: calendar))
    }

    @discardableResult
    public func append(_ capture: Capture) throws -> URL {
        guard !capture.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CaptureStoreError.emptyText
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = fileURL(for: capture.date)
        let entry = CaptureFormatter.entry(for: capture, calendar: calendar)

        if fileManager.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(entry.utf8))
        } else {
            let content = CaptureFormatter.fileHeader(for: capture.date, calendar: calendar) + entry
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    public func captures(on date: Date) -> [StoredCapture] {
        let day = calendar.startOfDay(for: date)
        guard let content = try? String(contentsOf: fileURL(for: day), encoding: .utf8) else { return [] }
        return CaptureFormatter.parse(content, day: day, calendar: calendar)
            .enumerated()
            .map { StoredCapture(day: day, index: $0.offset, capture: $0.element) }
    }

    /// Captures from `start` through `end` inclusive, oldest first.
    public func captures(from start: Date, through end: Date) -> [StoredCapture] {
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        var result: [StoredCapture] = []
        while day <= last {
            result += captures(on: day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    public func entryCount(on date: Date) -> Int {
        captures(on: date).count
    }

    public func update(_ stored: StoredCapture, text: String, categoryID: String?) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CaptureStoreError.emptyText }
        try rewrite(day: stored.day) { captures in
            guard captures.indices.contains(stored.index) else { throw CaptureStoreError.captureNotFound }
            captures[stored.index].text = trimmed
            captures[stored.index].categoryID = categoryID
        }
    }

    public func delete(_ stored: StoredCapture) throws {
        try rewrite(day: stored.day) { captures in
            guard captures.indices.contains(stored.index) else { throw CaptureStoreError.captureNotFound }
            captures.remove(at: stored.index)
        }
    }

    private func rewrite(day: Date, _ change: (inout [Capture]) throws -> Void) throws {
        var captures = self.captures(on: day).map(\.capture)
        try change(&captures)
        let url = fileURL(for: day)
        if captures.isEmpty {
            try fileManager.removeItem(at: url)
        } else {
            try CaptureFormatter.document(for: captures, day: day, calendar: calendar)
                .write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
