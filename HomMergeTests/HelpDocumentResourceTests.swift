import XCTest
@testable import HomMerge

final class HelpDocumentResourceTests: XCTestCase {
    func testEnglishPreferredLanguagesSelectEnglishHelpRTF() {
        XCTAssertEqual(
            HelpDocumentResource.rtfResourceName(preferredLanguages: ["en"]),
            "Help"
        )
        XCTAssertEqual(
            HelpDocumentResource.rtfResourceName(preferredLanguages: ["en-US"]),
            "Help"
        )
        XCTAssertEqual(
            HelpDocumentResource.rtfResourceName(preferredLanguages: ["en-US", "ja"]),
            "Help"
        )
    }

    func testJapanesePreferredLanguagesSelectJapaneseHelpRTF() {
        XCTAssertEqual(
            HelpDocumentResource.rtfResourceName(preferredLanguages: ["ja"]),
            "Help.ja"
        )
        XCTAssertEqual(
            HelpDocumentResource.rtfResourceName(preferredLanguages: ["ja-JP"]),
            "Help.ja"
        )
        XCTAssertEqual(
            HelpDocumentResource.rtfResourceName(preferredLanguages: ["ja-JP", "en"]),
            "Help.ja"
        )
    }

    func testEmptyPreferredLanguagesFallBackToEnglishHelpRTF() {
        XCTAssertEqual(
            HelpDocumentResource.rtfResourceName(preferredLanguages: []),
            "Help"
        )
    }

    func testProjectLinksPointAtHomMergeGitHub() {
        XCTAssertEqual(
            HomMergeProjectLinks.repositoryURL.absoluteString,
            "https://github.com/takenori-kabeya/HomMerge"
        )
        XCTAssertEqual(
            HomMergeProjectLinks.issuesURL.absoluteString,
            "https://github.com/takenori-kabeya/HomMerge/issues"
        )
    }
}
