@testable import ImpactCaptureCore
import XCTest

final class InsightsTests: XCTestCase {
    private let calendar = TestSupport.calendar
    private let weekdays: Set<Int> = [2, 3, 4, 5, 6]

    private func stored(day: Int, hour: Int = 10, text: String = "note", category: String? = nil, question: String? = nil) -> StoredCapture {
        StoredCapture(
            day: calendar.startOfDay(for: TestSupport.date(day: day, hour: 0)),
            index: 0,
            capture: Capture(
                date: TestSupport.date(day: day, hour: hour),
                source: .menu,
                question: question,
                text: text,
                categoryID: category,
                inputMethod: .typed
            )
        )
    }

    func test_stats_countsTodayAndWeek() {
        // Week of Mon 14 – Sun 20 September 2026.
        let captures = [stored(day: 11), stored(day: 14), stored(day: 16), stored(day: 17), stored(day: 17)]
        let stats = StatsCalculator.stats(captures: captures, now: TestSupport.date(hour: 12), workdays: weekdays, calendar: calendar)
        XCTAssertEqual(stats.today, 2)
        XCTAssertEqual(stats.thisWeek, 4)
    }

    func test_streak_skipsWeekendsAndDoesNotBreakOnEmptyToday() {
        // Fri 11, Mon 14, Tue 15, Wed 16 logged; Thu 17 (today) not yet.
        let captures = [stored(day: 11), stored(day: 14), stored(day: 15), stored(day: 16)]
        let stats = StatsCalculator.stats(captures: captures, now: TestSupport.date(hour: 12), workdays: weekdays, calendar: calendar)
        XCTAssertEqual(stats.streak, 4)
    }

    func test_streak_breaksOnMissedWorkday() {
        let captures = [stored(day: 14), stored(day: 16), stored(day: 17)]
        let stats = StatsCalculator.stats(captures: captures, now: TestSupport.date(hour: 12), workdays: weekdays, calendar: calendar)
        XCTAssertEqual(stats.streak, 2)
    }

    func test_export_groupsByDayWithBreakdown() {
        let categories = CaptureCategory.defaults
        let captures = [
            stored(day: 16, hour: 9, text: "Helped Ana with the flaky test", category: "unblocking"),
            stored(day: 17, hour: 10, text: "Coffee with Marco\nagreed to split PRs", category: "collaboration", question: "Talk to anyone?"),
            stored(day: 17, hour: 15, text: "Unsorted thought"),
        ]

        let markdown = CaptureExporter.markdown(
            captures,
            categories: categories,
            from: TestSupport.date(day: 14, hour: 0),
            through: TestSupport.date(day: 17, hour: 0),
            calendar: calendar
        )

        XCTAssertTrue(markdown.hasPrefix("# Impact log: 2026-09-14 to 2026-09-17\n"))
        XCTAssertTrue(markdown.contains("**3 captures** · Collaboration 1 · Unblocking 1 · Uncategorised 1"))
        XCTAssertTrue(markdown.contains("## Wednesday 16 September\n\n- **09:00** · _Unblocking_ · Helped Ana with the flaky test"))
        XCTAssertTrue(markdown.contains("- **10:00** · _Collaboration_ · Coffee with Marco agreed to split PRs\n  - Prompted by: \"Talk to anyone?\""))
        XCTAssertTrue(markdown.contains("- **15:00** · Unsorted thought"))
    }

    func test_export_empty() {
        let markdown = CaptureExporter.markdown([], categories: [], from: TestSupport.date(hour: 0), through: TestSupport.date(hour: 0), calendar: calendar)
        XCTAssertTrue(markdown.contains("_No captures in this period._"))
    }
}
