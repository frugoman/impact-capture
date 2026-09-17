@testable import ImpactCaptureCore
import XCTest

final class PromptPolicyTests: XCTestCase {
    private var settings = AppSettings()
    private var policy: PromptPolicy { PromptPolicy(settings: settings, calendar: TestSupport.calendar) }
    private let twentyMinutes: TimeInterval = 20 * 60

    func test_manual_alwaysAllowed() {
        settings.frequency = .off
        var state = PromptState()
        state.pausedUntil = TestSupport.date(day: 20, hour: 9)
        XCTAssertTrue(policy.shouldPrompt(.manual, now: TestSupport.date(day: 19, hour: 23), state: state, capturesToday: 9))
    }

    func test_awayReturn_requiresMeaningfulButNotHugeAbsence() {
        let now = TestSupport.date(hour: 11)
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: 5 * 60), now: now, state: PromptState(), capturesToday: 0))
        XCTAssertTrue(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: now, state: PromptState(), capturesToday: 0))
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: 10 * 3600), now: now, state: PromptState(), capturesToday: 0))
    }

    func test_awayReturn_respectsCustomThresholdAndToggle() {
        settings.minimumAwayMinutes = 30
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(hour: 11), state: PromptState(), capturesToday: 0))
        settings.minimumAwayMinutes = 10
        settings.awayPromptsEnabled = false
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(hour: 11), state: PromptState(), capturesToday: 0))
    }

    func test_frequencyOff_silencesAutomaticPrompts() {
        settings.frequency = .off
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(hour: 11), state: PromptState(), capturesToday: 0))
        XCTAssertFalse(policy.shouldPrompt(.endOfDay, now: TestSupport.date(hour: 17, minute: 45), state: PromptState(), capturesToday: 0))
    }

    func test_outsideWorkingHoursAndWorkdays_areQuiet() {
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(hour: 8), state: PromptState(), capturesToday: 0))
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(hour: 20), state: PromptState(), capturesToday: 0))
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(day: 19, hour: 11), state: PromptState(), capturesToday: 0))

        settings.workdays = [7] // Saturday only
        XCTAssertTrue(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(day: 19, hour: 11), state: PromptState(), capturesToday: 0))
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(hour: 11), state: PromptState(), capturesToday: 0))
    }

    func test_minimumGapBetweenPrompts() {
        let state = policy.recordingShown(.awayReturn(away: twentyMinutes), state: PromptState(), now: TestSupport.date(hour: 10))
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(hour: 10, minute: 30), state: state, capturesToday: 0))
        XCTAssertTrue(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(hour: 11), state: state, capturesToday: 0))
    }

    func test_dailyCapFollowsFrequency_andResetsNextDay() {
        var state = PromptState()
        for hour in [9, 11, 13] {
            state = policy.recordingShown(.awayReturn(away: twentyMinutes), state: state, now: TestSupport.date(hour: hour))
        }
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(hour: 15), state: state, capturesToday: 0))
        XCTAssertTrue(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(day: 18, hour: 10), state: state, capturesToday: 0))

        settings.frequency = .often
        XCTAssertTrue(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(hour: 15), state: state, capturesToday: 0))
    }

    func test_backsOffAfterRepeatedIgnores_andRecoversWhenAnswered() {
        var state = PromptState()
        for _ in 0..<3 {
            state = policy.recordingOutcome(.ignored, state: state)
        }
        state = policy.recordingShown(.awayReturn(away: twentyMinutes), state: state, now: TestSupport.date(day: 18, hour: 9))
        XCTAssertFalse(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(day: 18, hour: 12), state: state, capturesToday: 0))

        state = policy.recordingOutcome(.answered, state: state)
        XCTAssertTrue(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(day: 18, hour: 12), state: state, capturesToday: 0))
    }

    func test_endOfDay_onceInItsWindowAndSkippedWhenAlreadyLogged() {
        XCTAssertFalse(policy.shouldPrompt(.endOfDay, now: TestSupport.date(hour: 17, minute: 29), state: PromptState(), capturesToday: 0))
        XCTAssertTrue(policy.shouldPrompt(.endOfDay, now: TestSupport.date(hour: 17, minute: 30), state: PromptState(), capturesToday: 0))
        XCTAssertFalse(policy.shouldPrompt(.endOfDay, now: TestSupport.date(hour: 17, minute: 30), state: PromptState(), capturesToday: 3))
        XCTAssertFalse(policy.shouldPrompt(.endOfDay, now: TestSupport.date(hour: 21), state: PromptState(), capturesToday: 0))

        let state = policy.recordingShown(.endOfDay, state: PromptState(), now: TestSupport.date(hour: 17, minute: 30))
        XCTAssertFalse(policy.shouldPrompt(.endOfDay, now: TestSupport.date(hour: 18, minute: 30), state: state, capturesToday: 0))
    }

    func test_nextWorkdayStart_skipsWeekend() {
        XCTAssertEqual(policy.nextWorkdayStart(after: TestSupport.date(hour: 11)), TestSupport.date(day: 18, hour: 9))
        XCTAssertEqual(policy.nextWorkdayStart(after: TestSupport.date(day: 18, hour: 16)), TestSupport.date(day: 21, hour: 9))
    }

    func test_pausedUntil_blocksAutomaticPromptsOnly() {
        let state = policy.paused(PromptState(), until: TestSupport.date(day: 18, hour: 9))
        XCTAssertFalse(policy.shouldPrompt(.endOfDay, now: TestSupport.date(hour: 17, minute: 45), state: state, capturesToday: 0))
        XCTAssertTrue(policy.shouldPrompt(.awayReturn(away: twentyMinutes), now: TestSupport.date(day: 18, hour: 9, minute: 5), state: state, capturesToday: 0))
    }

    func test_questionBank_rotatesEnabledQuestionsOfTheRightKind() {
        var questions = PromptQuestion.defaults
        let first = QuestionBank.question(for: .endOfDay, rotation: 0, from: questions)
        let second = QuestionBank.question(for: .endOfDay, rotation: 1, from: questions)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(
            QuestionBank.question(for: .awayReturn(away: 25 * 60), rotation: 0, from: questions)?.text,
            "You were away 25 min. Did you talk to anyone about work?"
        )

        for index in questions.indices where questions[index].kind == .awayReturn {
            questions[index].isEnabled = false
        }
        XCTAssertNil(QuestionBank.question(for: .awayReturn(away: 25 * 60), rotation: 0, from: questions))
    }
}
