@testable import ImpactCaptureCore
import XCTest

final class CaptureStoreTests: XCTestCase {
    private var directory: URL!
    private var store: CaptureStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = CaptureStore(directory: directory, calendar: TestSupport.calendar)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_append_createsDailyFileWithHeaderAndEntry() throws {
        let capture = Capture(
            date: TestSupport.date(hour: 10, minute: 42),
            source: .prompt,
            trigger: "away-return",
            question: "Did you talk to anyone about work?",
            text: "  Coffee with Marco, agreed to split the migration into two PRs.\n",
            categoryID: "collaboration",
            inputMethod: .voice
        )

        let url = try store.append(capture)

        XCTAssertEqual(url.lastPathComponent, "2026-09-17.md")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), """
        # Impact captures — 2026-09-17 (Thursday)

        Self-reported notes captured in the moment. Unverified: treat them as memory joggers and \
        corroborate with Slack, Jira, Confluence, GitHub or calendar evidence where possible.

        ### 10:42 · prompt · away-return · voice · #collaboration

        > Q: Did you talk to anyone about work?

        Coffee with Marco, agreed to split the migration into two PRs.

        """)
    }

    func test_append_addsToExistingFileWithoutRepeatingHeader() throws {
        try store.append(Capture(date: TestSupport.date(hour: 10), source: .raycast, text: "First", inputMethod: .typed))
        try store.append(Capture(date: TestSupport.date(hour: 11), source: .raycast, text: "Second", inputMethod: .typed))

        let content = try String(contentsOf: store.fileURL(for: TestSupport.date(hour: 12)), encoding: .utf8)
        XCTAssertEqual(content.components(separatedBy: "# Impact captures").count - 1, 1)
        XCTAssertTrue(content.hasSuffix("### 11:00 · raycast · typed\n\nSecond\n"))
        XCTAssertEqual(store.entryCount(on: TestSupport.date(hour: 12)), 2)
    }

    func test_append_rejectsBlankText() {
        let capture = Capture(date: TestSupport.date(hour: 10), source: .menu, text: " \n ", inputMethod: .typed)
        XCTAssertThrowsError(try store.append(capture)) { error in
            XCTAssertEqual(error as? CaptureStoreError, .emptyText)
        }
    }

    func test_captures_roundTripEveryField() throws {
        let original = Capture(
            date: TestSupport.date(hour: 9, minute: 5),
            source: .prompt,
            trigger: "end-of-day",
            question: "Did you help someone get unstuck today?",
            text: "Paired with Ana on the flaky test.\nWe found the race.",
            categoryID: "unblocking",
            inputMethod: .voice
        )
        try store.append(original)
        try store.append(Capture(date: TestSupport.date(hour: 16), source: .shortcut, text: "Quick one", inputMethod: .typed))

        let captures = store.captures(on: TestSupport.date(hour: 23))
        XCTAssertEqual(captures.map(\.capture), [
            original,
            Capture(date: TestSupport.date(hour: 16), source: .shortcut, text: "Quick one", inputMethod: .typed),
        ])
        XCTAssertEqual(captures.map(\.index), [0, 1])
    }

    func test_captures_acrossDays() throws {
        try store.append(Capture(date: TestSupport.date(day: 15, hour: 10), source: .menu, text: "Mon", inputMethod: .typed))
        try store.append(Capture(date: TestSupport.date(day: 17, hour: 10), source: .menu, text: "Wed", inputMethod: .typed))
        try store.append(Capture(date: TestSupport.date(day: 18, hour: 10), source: .menu, text: "Thu", inputMethod: .typed))

        let texts = store.captures(from: TestSupport.date(day: 15, hour: 0), through: TestSupport.date(day: 17, hour: 0))
            .map(\.capture.text)
        XCTAssertEqual(texts, ["Mon", "Wed"])
    }

    func test_update_changesTextAndCategoryInPlace() throws {
        try store.append(Capture(date: TestSupport.date(hour: 10), source: .menu, text: "First", inputMethod: .typed))
        try store.append(Capture(date: TestSupport.date(hour: 11), source: .menu, text: "Second", inputMethod: .typed))

        let second = store.captures(on: TestSupport.date(hour: 12))[1]
        try store.update(second, text: " Second, edited ", categoryID: "mentoring")

        let captures = store.captures(on: TestSupport.date(hour: 12)).map(\.capture)
        XCTAssertEqual(captures.map(\.text), ["First", "Second, edited"])
        XCTAssertEqual(captures.map(\.categoryID), [nil, "mentoring"])
    }

    func test_delete_removesEntryAndFileWhenEmpty() throws {
        try store.append(Capture(date: TestSupport.date(hour: 10), source: .menu, text: "First", inputMethod: .typed))
        try store.append(Capture(date: TestSupport.date(hour: 11), source: .menu, text: "Second", inputMethod: .typed))

        try store.delete(store.captures(on: TestSupport.date(hour: 12))[0])
        XCTAssertEqual(store.captures(on: TestSupport.date(hour: 12)).map(\.capture.text), ["Second"])

        try store.delete(store.captures(on: TestSupport.date(hour: 12))[0])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL(for: TestSupport.date(hour: 12)).path))
    }

    func test_delete_staleIndexThrows() throws {
        try store.append(Capture(date: TestSupport.date(hour: 10), source: .menu, text: "Only", inputMethod: .typed))
        let stale = StoredCapture(day: TestSupport.date(hour: 0), index: 3, capture: Capture(date: Date(), source: .menu, text: "x", inputMethod: .typed))
        XCTAssertThrowsError(try store.delete(stale)) { error in
            XCTAssertEqual(error as? CaptureStoreError, .captureNotFound)
        }
    }
}
