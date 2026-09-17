import Foundation

public enum CategoryColor: String, Codable, CaseIterable, Identifiable {
    case coral, amber, lime, teal, sky, violet, pink, slate

    public var id: String { rawValue }
}

public struct CaptureCategory: Codable, Identifiable, Hashable {
    /// Stable slug written into files as `#id`. Renaming a category keeps its id.
    public var id: String
    public var name: String
    public var color: CategoryColor

    public init(id: String, name: String, color: CategoryColor) {
        self.id = id
        self.name = name
        self.color = color
    }

    public static let defaults: [CaptureCategory] = [
        CaptureCategory(id: "collaboration", name: "Collaboration", color: .sky),
        CaptureCategory(id: "unblocking", name: "Unblocking", color: .lime),
        CaptureCategory(id: "influence", name: "Influence", color: .violet),
        CaptureCategory(id: "mentoring", name: "Mentoring", color: .amber),
        CaptureCategory(id: "risk", name: "Risk spotted", color: .coral),
        CaptureCategory(id: "recognition", name: "Recognition", color: .pink),
    ]

    /// Makes a slug from `name` that doesn't clash with `existing` ids.
    public static func makeID(from name: String, existing: [String]) -> String {
        let base = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let root = base.isEmpty ? "category" : base
        var candidate = root
        var suffix = 2
        while existing.contains(candidate) {
            candidate = "\(root)-\(suffix)"
            suffix += 1
        }
        return candidate
    }
}

public enum QuestionKind: String, Codable, CaseIterable {
    /// Asked when you come back to your Mac. `{minutes}` is replaced with the time away.
    case awayReturn
    /// Asked at the end of the day or on demand.
    case reflective
}

public struct PromptQuestion: Codable, Identifiable, Equatable {
    public var id: UUID
    public var kind: QuestionKind
    public var text: String
    public var followUp: String
    public var categoryID: String?
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        kind: QuestionKind,
        text: String,
        followUp: String,
        categoryID: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.followUp = followUp
        self.categoryID = categoryID
        self.isEnabled = isEnabled
    }

    public static var defaults: [PromptQuestion] {
        [
            PromptQuestion(
                kind: .awayReturn,
                text: "You were away {minutes} min. Did you talk to anyone about work?",
                followUp: "Who was it, and what came out of it?"
            ),
            PromptQuestion(
                kind: .awayReturn,
                text: "Back after {minutes} min. Did that break turn into a work conversation?",
                followUp: "What did you discuss, and did you land on anything?"
            ),
            PromptQuestion(
                kind: .reflective,
                text: "Did a conversation change how you or someone else approaches a problem?",
                followUp: "What changed, and who was involved?",
                categoryID: "influence"
            ),
            PromptQuestion(
                kind: .reflective,
                text: "Did you help someone get unstuck today?",
                followUp: "Who was it, and what was blocking them?",
                categoryID: "unblocking"
            ),
            PromptQuestion(
                kind: .reflective,
                text: "Did you give feedback, advice or mentoring today?",
                followUp: "Who was it for, and what did you share?",
                categoryID: "mentoring"
            ),
            PromptQuestion(
                kind: .reflective,
                text: "Did you work with, or hear from, someone outside your team?",
                followUp: "Which team, and what was it about?",
                categoryID: "collaboration"
            ),
            PromptQuestion(
                kind: .reflective,
                text: "Did you spot a risk or problem before it grew?",
                followUp: "What was it, and who knows about it now?",
                categoryID: "risk"
            ),
            PromptQuestion(
                kind: .reflective,
                text: "Did someone thank you or recognise something you did?",
                followUp: "Who was it, and what for?",
                categoryID: "recognition"
            ),
            PromptQuestion(
                kind: .reflective,
                text: "Did you make or shape a decision that isn't written down anywhere?",
                followUp: "What was decided, and why?",
                categoryID: "influence"
            ),
        ]
    }
}

public enum PromptFrequency: String, Codable, CaseIterable, Identifiable {
    case off, rarely, normal, often

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: return "Off"
        case .rarely: return "Rarely"
        case .normal: return "Normal"
        case .often: return "Often"
        }
    }

    public var detail: String {
        switch self {
        case .off: return "Only when you ask"
        case .rarely: return "1 check-in a day"
        case .normal: return "Up to 3 a day, 45 min apart"
        case .often: return "Up to 5 a day, 30 min apart"
        }
    }

    public var dailyCap: Int {
        switch self {
        case .off: return 0
        case .rarely: return 1
        case .normal: return 3
        case .often: return 5
        }
    }

    public var minimumGap: TimeInterval {
        switch self {
        case .off, .rarely: return 2 * 60 * 60
        case .normal: return 45 * 60
        case .often: return 30 * 60
        }
    }
}

/// A global shortcut stored as a virtual key code plus Carbon modifier flags.
public struct ShortcutSpec: Codable, Equatable {
    public static let command: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000

    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    private static let keyL: UInt32 = 0x25
    public static let defaultTyping = ShortcutSpec(keyCode: keyL, modifiers: control | option)
    public static let defaultVoice = ShortcutSpec(keyCode: keyL, modifiers: control | option | command)
}

public struct AppSettings: Codable, Equatable {
    public var hasCompletedOnboarding = false
    public var capturesFolderPath = AppSettings.defaultCapturesFolder.path
    /// `Calendar` weekday numbers: 1 is Sunday, 7 is Saturday.
    public var workdays: Set<Int> = [2, 3, 4, 5, 6]
    public var workdayStartHour = 9
    public var workdayEndHour = 18
    public var frequency = PromptFrequency.normal
    public var awayPromptsEnabled = true
    public var minimumAwayMinutes = 15
    public var endOfDayEnabled = true
    public var endOfDayHour = 17
    public var endOfDayMinute = 30
    public var categories = CaptureCategory.defaults
    public var questions = PromptQuestion.defaults
    public var typingShortcut: ShortcutSpec? = .defaultTyping
    public var voiceShortcut: ShortcutSpec? = .defaultVoice
    public var speechLocaleIdentifier = "en-US"

    public static var defaultCapturesFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Impact Capture", isDirectory: true)
    }

    public var capturesFolder: URL {
        URL(fileURLWithPath: (capturesFolderPath as NSString).expandingTildeInPath, isDirectory: true)
    }

    public func category(withID id: String?) -> CaptureCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding, capturesFolderPath, workdays, workdayStartHour, workdayEndHour
        case frequency, awayPromptsEnabled, minimumAwayMinutes, endOfDayEnabled, endOfDayHour, endOfDayMinute
        case categories, questions, typingShortcut, voiceShortcut, speechLocaleIdentifier
    }

    /// Missing keys fall back to defaults so settings survive app updates that add new options.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        hasCompletedOnboarding = value(.hasCompletedOnboarding, defaults.hasCompletedOnboarding)
        capturesFolderPath = value(.capturesFolderPath, defaults.capturesFolderPath)
        workdays = value(.workdays, defaults.workdays)
        workdayStartHour = value(.workdayStartHour, defaults.workdayStartHour)
        workdayEndHour = value(.workdayEndHour, defaults.workdayEndHour)
        frequency = value(.frequency, defaults.frequency)
        awayPromptsEnabled = value(.awayPromptsEnabled, defaults.awayPromptsEnabled)
        minimumAwayMinutes = value(.minimumAwayMinutes, defaults.minimumAwayMinutes)
        endOfDayEnabled = value(.endOfDayEnabled, defaults.endOfDayEnabled)
        endOfDayHour = value(.endOfDayHour, defaults.endOfDayHour)
        endOfDayMinute = value(.endOfDayMinute, defaults.endOfDayMinute)
        categories = value(.categories, defaults.categories)
        questions = value(.questions, defaults.questions)
        speechLocaleIdentifier = value(.speechLocaleIdentifier, defaults.speechLocaleIdentifier)
        // A stored null means the user cleared the shortcut, so only a missing key uses the default.
        typingShortcut = container.contains(.typingShortcut)
            ? (try? container.decodeIfPresent(ShortcutSpec.self, forKey: .typingShortcut)) ?? nil
            : defaults.typingShortcut
        voiceShortcut = container.contains(.voiceShortcut)
            ? (try? container.decodeIfPresent(ShortcutSpec.self, forKey: .voiceShortcut)) ?? nil
            : defaults.voiceShortcut
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(capturesFolderPath, forKey: .capturesFolderPath)
        try container.encode(workdays, forKey: .workdays)
        try container.encode(workdayStartHour, forKey: .workdayStartHour)
        try container.encode(workdayEndHour, forKey: .workdayEndHour)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(awayPromptsEnabled, forKey: .awayPromptsEnabled)
        try container.encode(minimumAwayMinutes, forKey: .minimumAwayMinutes)
        try container.encode(endOfDayEnabled, forKey: .endOfDayEnabled)
        try container.encode(endOfDayHour, forKey: .endOfDayHour)
        try container.encode(endOfDayMinute, forKey: .endOfDayMinute)
        try container.encode(categories, forKey: .categories)
        try container.encode(questions, forKey: .questions)
        try container.encode(typingShortcut, forKey: .typingShortcut)
        try container.encode(voiceShortcut, forKey: .voiceShortcut)
        try container.encode(speechLocaleIdentifier, forKey: .speechLocaleIdentifier)
    }
}
