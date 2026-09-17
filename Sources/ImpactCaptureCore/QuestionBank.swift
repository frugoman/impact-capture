import Foundation

public struct Question: Equatable {
    public var text: String
    public var followUp: String
    public var categoryID: String?

    public init(text: String, followUp: String, categoryID: String? = nil) {
        self.text = text
        self.followUp = followUp
        self.categoryID = categoryID
    }
}

public enum QuestionBank {
    /// Picks the next enabled question for `trigger`, or `nil` when the user disabled all of them.
    public static func question(
        for trigger: PromptTrigger,
        rotation: Int,
        from questions: [PromptQuestion]
    ) -> Question? {
        let kind: QuestionKind
        if case .awayReturn = trigger {
            kind = .awayReturn
        } else {
            kind = .reflective
        }

        let pool = questions.filter { $0.isEnabled && $0.kind == kind }
        guard !pool.isEmpty else { return nil }
        let picked = pool[abs(rotation) % pool.count]

        var text = picked.text
        if case let .awayReturn(away) = trigger {
            text = text.replacingOccurrences(of: "{minutes}", with: "\(Int(away / 60))")
        }
        return Question(text: text, followUp: picked.followUp, categoryID: picked.categoryID)
    }
}
