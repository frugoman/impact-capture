@testable import ImpactCaptureCore
import XCTest

final class SettingsTests: XCTestCase {
    func test_decodingOlderSettings_fillsNewFieldsWithDefaults() throws {
        let json = #"{"hasCompletedOnboarding": true, "frequency": "often", "workdays": [2, 3]}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))

        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.frequency, .often)
        XCTAssertEqual(settings.workdays, [2, 3])
        XCTAssertEqual(settings.categories, CaptureCategory.defaults)
        XCTAssertEqual(settings.typingShortcut, .defaultTyping)
    }

    func test_clearedShortcutSurvivesRoundTrip() throws {
        var settings = AppSettings()
        settings.voiceShortcut = nil
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertNil(decoded.voiceShortcut)
        XCTAssertEqual(decoded.typingShortcut, .defaultTyping)
        XCTAssertEqual(decoded, settings)
    }

    func test_categoryIDs_areSlugsWithoutClashes() {
        XCTAssertEqual(CaptureCategory.makeID(from: "Cross-team Work!", existing: []), "cross-team-work")
        XCTAssertEqual(CaptureCategory.makeID(from: "Mentoring", existing: ["mentoring", "mentoring-2"]), "mentoring-3")
        XCTAssertEqual(CaptureCategory.makeID(from: "🙂", existing: []), "category")
    }

    func test_defaultQuestions_referenceExistingCategories() {
        let ids = Set(CaptureCategory.defaults.map(\.id))
        for question in PromptQuestion.defaults {
            if let categoryID = question.categoryID {
                XCTAssertTrue(ids.contains(categoryID), "\(categoryID) is not a default category")
            }
        }
    }
}
