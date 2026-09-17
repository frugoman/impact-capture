@testable import ImpactCaptureCore
import XCTest

final class URLCommandTests: XCTestCase {
    func test_log_withTextAndCategory() {
        let url = URL(string: "impactcapture://log?text=Aligned%20with%20Tuxedo%20on%20scope&category=Collaboration")!
        XCTAssertEqual(URLCommand(url: url), .log(text: "Aligned with Tuxedo on scope", categoryID: "collaboration"))
    }

    func test_tagIsAnAliasForCategory() {
        let url = URL(string: "impactcapture://log?text=hi&tag=risk")!
        XCTAssertEqual(URLCommand(url: url), .log(text: "hi", categoryID: "risk"))
    }

    func test_log_withoutTextOpensComposer() {
        XCTAssertEqual(URLCommand(url: URL(string: "impactcapture://log?text=%20&category=")!), .compose(voice: false, categoryID: nil))
    }

    func test_voice() {
        XCTAssertEqual(URLCommand(url: URL(string: "impactcapture://voice")!), .compose(voice: true, categoryID: nil))
    }

    func test_ask() {
        XCTAssertEqual(URLCommand(url: URL(string: "impactcapture://ask")!), .ask)
    }

    func test_rejectsOtherSchemesAndActions() {
        XCTAssertNil(URLCommand(url: URL(string: "https://log?text=hi")!))
        XCTAssertNil(URLCommand(url: URL(string: "impactcapture://delete")!))
    }
}
