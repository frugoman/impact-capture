import Foundation

/// Commands accepted through the `impactcapture://` URL scheme (used by Raycast and scripts).
///
/// - `impactcapture://log?text=…&category=collaboration` saves a note silently.
/// - `impactcapture://compose?category=…` opens the capture panel for typing.
/// - `impactcapture://voice?category=…` opens the capture panel and starts listening.
/// - `impactcapture://ask` shows a check-in question right now.
///
/// `tag` is accepted as an alias of `category`.
public enum URLCommand: Equatable {
    case log(text: String, categoryID: String?)
    case compose(voice: Bool, categoryID: String?)
    case ask

    public static let scheme = "impactcapture"

    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            queryItems.first { $0.name == name }?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let categoryID = (value("category") ?? value("tag")).flatMap { $0.isEmpty ? nil : $0.lowercased() }

        switch url.host?.lowercased() {
        case "log":
            let text = value("text") ?? ""
            self = text.isEmpty ? .compose(voice: false, categoryID: categoryID) : .log(text: text, categoryID: categoryID)
        case "compose":
            self = .compose(voice: false, categoryID: categoryID)
        case "voice":
            self = .compose(voice: true, categoryID: categoryID)
        case "ask":
            self = .ask
        default:
            return nil
        }
    }
}
