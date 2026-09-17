import Foundation

public enum PromptTrigger: Equatable {
    /// The Mac was locked or idle for `away` seconds and the user just came back.
    case awayReturn(away: TimeInterval)
    case endOfDay
    case manual

    public var identifier: String {
        switch self {
        case .awayReturn: return "away-return"
        case .endOfDay: return "end-of-day"
        case .manual: return "manual"
        }
    }
}

public enum PromptOutcome {
    case answered
    case declined
    case ignored
}

public struct PromptState: Codable, Equatable {
    public var day = ""
    public var promptsShown = 0
    public var lastPromptAt: Date?
    public var endOfDayShown = false
    public var consecutiveIgnores = 0
    public var pausedUntil: Date?
    public var questionRotation = 0

    public init() {}
}

/// Decides when the app is allowed to interrupt. Kept pure so it can be unit tested.
public struct PromptPolicy {
    public var settings: AppSettings
    /// Cap used after the user ignored several prompts in a row.
    public var reducedDailyCap = 1
    public var ignoresBeforeBackoff = 3
    /// Longer absences are lunch, the commute or the night, not a conversation.
    public var maximumAway: TimeInterval = 3 * 60 * 60
    /// End of day is skipped when the user already logged this much on their own.
    public var skipEndOfDayAfterCaptures = 3
    public var calendar: Calendar

    public init(settings: AppSettings = AppSettings(), calendar: Calendar = .current) {
        self.settings = settings
        self.calendar = calendar
    }

    public var minimumAway: TimeInterval {
        TimeInterval(settings.minimumAwayMinutes * 60)
    }

    public func dayKey(for date: Date) -> String {
        CaptureFormatter.dayString(for: date, calendar: calendar)
    }

    public func rolledOver(_ state: PromptState, now: Date) -> PromptState {
        let key = dayKey(for: now)
        guard state.day != key else { return state }
        var fresh = PromptState()
        fresh.day = key
        fresh.consecutiveIgnores = state.consecutiveIgnores
        fresh.pausedUntil = state.pausedUntil
        fresh.questionRotation = state.questionRotation
        return fresh
    }

    public func isPaused(_ state: PromptState, now: Date) -> Bool {
        guard let pausedUntil = state.pausedUntil else { return false }
        return now < pausedUntil
    }

    public func effectiveDailyCap(_ state: PromptState) -> Int {
        let cap = settings.frequency.dailyCap
        return state.consecutiveIgnores >= ignoresBeforeBackoff ? min(cap, reducedDailyCap) : cap
    }

    public func shouldPrompt(
        _ trigger: PromptTrigger,
        now: Date,
        state storedState: PromptState,
        capturesToday: Int
    ) -> Bool {
        if case .manual = trigger { return true }

        let state = rolledOver(storedState, now: now)
        guard settings.frequency != .off, !isPaused(state, now: now), isWorkday(now) else { return false }
        if let last = state.lastPromptAt, now.timeIntervalSince(last) < settings.frequency.minimumGap {
            return false
        }

        switch trigger {
        case let .awayReturn(away):
            return settings.awayPromptsEnabled
                && isWorkingHours(now)
                && away >= minimumAway
                && away <= maximumAway
                && state.promptsShown < effectiveDailyCap(state)
        case .endOfDay:
            return settings.endOfDayEnabled
                && !state.endOfDayShown
                && capturesToday < skipEndOfDayAfterCaptures
                && isEndOfDayWindow(now)
        case .manual:
            return true
        }
    }

    public func recordingShown(_ trigger: PromptTrigger, state: PromptState, now: Date) -> PromptState {
        var state = rolledOver(state, now: now)
        state.lastPromptAt = now
        state.questionRotation += 1
        switch trigger {
        case .awayReturn: state.promptsShown += 1
        case .endOfDay: state.endOfDayShown = true
        case .manual: break
        }
        return state
    }

    public func recordingOutcome(_ outcome: PromptOutcome, state: PromptState) -> PromptState {
        var state = state
        switch outcome {
        case .answered, .declined: state.consecutiveIgnores = 0
        case .ignored: state.consecutiveIgnores += 1
        }
        return state
    }

    public func paused(_ state: PromptState, until date: Date?) -> PromptState {
        var state = state
        state.pausedUntil = date
        return state
    }

    /// The start of the next working day.
    public func nextWorkdayStart(after now: Date) -> Date {
        var day = calendar.startOfDay(for: now)
        for _ in 0..<7 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            if settings.workdays.isEmpty || isWorkday(day) { break }
        }
        return calendar.date(bySettingHour: settings.workdayStartHour, minute: 0, second: 0, of: day) ?? day
    }

    private func isWorkday(_ date: Date) -> Bool {
        settings.workdays.contains(calendar.component(.weekday, from: date))
    }

    private func isWorkingHours(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= settings.workdayStartHour && hour < settings.workdayEndHour
    }

    /// From the end-of-day time until two hours later (or the end of the workday, if later).
    private func isEndOfDayWindow(_ date: Date) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let start = settings.endOfDayHour * 60 + settings.endOfDayMinute
        let end = max(settings.workdayEndHour * 60, start + 120)
        return minutes >= start && minutes < end
    }
}
