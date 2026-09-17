import Foundation

public enum CaptureSource: String, Codable {
    case prompt
    case raycast
    case menu
    case shortcut
}

public enum InputMethod: String, Codable {
    case voice
    case typed
}

public struct Capture: Equatable {
    public var date: Date
    public var source: CaptureSource
    public var trigger: String?
    public var question: String?
    public var text: String
    /// The `id` of a `CaptureCategory`, written as `#id` in the Markdown file.
    public var categoryID: String?
    public var inputMethod: InputMethod

    public init(
        date: Date,
        source: CaptureSource,
        trigger: String? = nil,
        question: String? = nil,
        text: String,
        categoryID: String? = nil,
        inputMethod: InputMethod
    ) {
        self.date = date
        self.source = source
        self.trigger = trigger
        self.question = question
        self.text = text
        self.categoryID = categoryID
        self.inputMethod = inputMethod
    }
}

/// A capture read back from disk. `index` is its position within that day's file.
public struct StoredCapture: Identifiable, Equatable {
    public let day: Date
    public let index: Int
    public var capture: Capture

    public var id: String { "\(day.timeIntervalSinceReferenceDate)#\(index)" }

    public init(day: Date, index: Int, capture: Capture) {
        self.day = day
        self.index = index
        self.capture = capture
    }
}
