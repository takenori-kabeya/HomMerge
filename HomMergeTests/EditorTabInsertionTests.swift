import AppKit
import XCTest
@testable import HomMerge

final class EditorTabInsertionTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "HomMerge.EditorTabInsertionTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDisplayColumnCountsCharactersAndExpandsTabs() {
        XCTAssertEqual(EditorPreferences.displayColumn(linePrefix: "", tabWidth: 4), 0)
        XCTAssertEqual(EditorPreferences.displayColumn(linePrefix: "a", tabWidth: 4), 1)
        XCTAssertEqual(EditorPreferences.displayColumn(linePrefix: "abcd", tabWidth: 4), 4)
        XCTAssertEqual(EditorPreferences.displayColumn(linePrefix: "\t", tabWidth: 4), 4)
        XCTAssertEqual(EditorPreferences.displayColumn(linePrefix: "a\t", tabWidth: 4), 4)
        XCTAssertEqual(EditorPreferences.displayColumn(linePrefix: "ab\t", tabWidth: 4), 4)
        XCTAssertEqual(EditorPreferences.displayColumn(linePrefix: "\t\t", tabWidth: 4), 8)
    }

    func testSpacesToNextTabStop() {
        XCTAssertEqual(EditorPreferences.spacesToNextTabStop(column: 0, tabWidth: 4), 4)
        XCTAssertEqual(EditorPreferences.spacesToNextTabStop(column: 1, tabWidth: 4), 3)
        XCTAssertEqual(EditorPreferences.spacesToNextTabStop(column: 4, tabWidth: 4), 4)
        XCTAssertEqual(EditorPreferences.spacesToNextTabStop(column: 1, tabWidth: 2), 1)
    }

    func testInsertionStringUsesHardTabWhenSpacesDisabled() {
        defaults.set(false, forKey: EditorPreferences.tabInsertsSpacesKey)
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)

        XCTAssertEqual(
            EditorPreferences.insertionString(linePrefixBeforeCaret: "abc", defaults: defaults),
            "\t"
        )
    }

    func testInsertionStringAlignsToTabStopWhenSpacesEnabled() {
        defaults.set(true, forKey: EditorPreferences.tabInsertsSpacesKey)
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)

        XCTAssertEqual(
            EditorPreferences.insertionString(linePrefixBeforeCaret: "", defaults: defaults),
            "    "
        )
        XCTAssertEqual(
            EditorPreferences.insertionString(linePrefixBeforeCaret: "a", defaults: defaults),
            "   "
        )
        XCTAssertEqual(
            EditorPreferences.insertionString(linePrefixBeforeCaret: "abcd", defaults: defaults),
            "    "
        )

        defaults.set(2, forKey: EditorPreferences.tabWidthKey)
        XCTAssertEqual(
            EditorPreferences.insertionString(linePrefixBeforeCaret: "a", defaults: defaults),
            " "
        )
    }

    @MainActor
    func testInsertTabInsertsSpacesAlignedToTabStop() {
        defaults.set(true, forKey: EditorPreferences.tabInsertsSpacesKey)
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)

        let textView = DiffPaneContentTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = "a"
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        textView.editorDefaults = defaults

        textView.insertTab(nil)

        XCTAssertEqual(textView.string, "a   ")
    }

    @MainActor
    func testInsertTabInsertsHardTabWhenConfigured() {
        defaults.set(false, forKey: EditorPreferences.tabInsertsSpacesKey)

        let textView = DiffPaneContentTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = ""
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.editorDefaults = defaults

        textView.insertTab(nil)

        XCTAssertEqual(textView.string, "\t")
    }

    func testDefaultTabIntervalMatchesSpaceAdvanceTimesWidth() {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width

        let interval2 = EditorPreferences.defaultTabInterval(font: font, tabWidth: 2)
        let interval4 = EditorPreferences.defaultTabInterval(font: font, tabWidth: 4)

        XCTAssertEqual(interval2, spaceWidth * 2, accuracy: 0.001)
        XCTAssertEqual(interval4, spaceWidth * 4, accuracy: 0.001)
        XCTAssertEqual(interval4 / interval2, 2, accuracy: 0.001)
    }

    func testClampedTabWidthAcceptsAllowedValues() {
        XCTAssertEqual(EditorPreferences.clampedTabWidth(2), 2)
        XCTAssertEqual(EditorPreferences.clampedTabWidth(4), 4)
        XCTAssertEqual(EditorPreferences.clampedTabWidth(8), 8)
        XCTAssertEqual(EditorPreferences.clampedTabWidth(0), EditorPreferences.defaultTabWidth)
        XCTAssertEqual(EditorPreferences.clampedTabWidth(3), EditorPreferences.defaultTabWidth)
    }

    func testResolvedTabWidthDoesNotWriteDefaultsWhenUnset() {
        XCTAssertNil(defaults.object(forKey: EditorPreferences.tabWidthKey))
        XCTAssertEqual(EditorPreferences.resolvedTabWidth(defaults: defaults), EditorPreferences.defaultTabWidth)
        XCTAssertNil(defaults.object(forKey: EditorPreferences.tabWidthKey))
    }

    func testClampedTabWidthDoesNotWriteDefaults() {
        defaults.set(0, forKey: EditorPreferences.tabWidthKey)
        let before = defaults.integer(forKey: EditorPreferences.tabWidthKey)
        XCTAssertEqual(EditorPreferences.clampedTabWidth(before), EditorPreferences.defaultTabWidth)
        XCTAssertEqual(defaults.integer(forKey: EditorPreferences.tabWidthKey), 0)
    }

    func testLeadingUnindentLength() {
        XCTAssertEqual(EditorPreferences.leadingUnindentLength(line: "\tabc", tabWidth: 4), 1)
        XCTAssertEqual(EditorPreferences.leadingUnindentLength(line: "    abc", tabWidth: 4), 4)
        XCTAssertEqual(EditorPreferences.leadingUnindentLength(line: "  abc", tabWidth: 4), 2)
        XCTAssertEqual(EditorPreferences.leadingUnindentLength(line: "abc", tabWidth: 4), 0)
        XCTAssertEqual(EditorPreferences.leadingUnindentLength(line: "\t  x", tabWidth: 4), 1)
        XCTAssertEqual(EditorPreferences.leadingUnindentLength(line: "     x", tabWidth: 4), 4)
        XCTAssertEqual(EditorPreferences.leadingUnindentLength(line: "  x", tabWidth: 2), 2)
    }

    @MainActor
    func testInsertBacktabRemovesLeadingSpaces() {
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)

        let textView = DiffPaneContentTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = "    hello"
        textView.setSelectedRange(NSRange(location: 4, length: 0))
        textView.editorDefaults = defaults

        textView.insertBacktab(nil)

        XCTAssertEqual(textView.string, "hello")
    }

    @MainActor
    func testInsertBacktabRemovesLeadingTab() {
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)

        let textView = DiffPaneContentTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = "\thello"
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        textView.editorDefaults = defaults

        textView.insertBacktab(nil)

        XCTAssertEqual(textView.string, "hello")
    }

    @MainActor
    func testInsertBacktabLeavesUnindentedLineUnchanged() {
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)

        let textView = DiffPaneContentTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = "hello"
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        textView.editorDefaults = defaults

        textView.insertBacktab(nil)

        XCTAssertEqual(textView.string, "hello")
    }

    @MainActor
    func testInsertBacktabUnindentsEachSelectedLine() {
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)

        let textView = DiffPaneContentTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = "\tone\n    two\nthree"
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.utf16.count))
        textView.editorDefaults = defaults

        textView.insertBacktab(nil)

        XCTAssertEqual(textView.string, "one\ntwo\nthree")
    }

    func testLineIndentPrefixUsesSpacesOrTab() {
        defaults.set(true, forKey: EditorPreferences.tabInsertsSpacesKey)
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)
        XCTAssertEqual(EditorPreferences.lineIndentPrefix(defaults: defaults), "    ")

        defaults.set(false, forKey: EditorPreferences.tabInsertsSpacesKey)
        XCTAssertEqual(EditorPreferences.lineIndentPrefix(defaults: defaults), "\t")
    }

    @MainActor
    func testInsertTabIndentsEachSelectedLineWithSpaces() {
        defaults.set(true, forKey: EditorPreferences.tabInsertsSpacesKey)
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)

        let textView = DiffPaneContentTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = "a\nb"
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.utf16.count))
        textView.editorDefaults = defaults

        textView.insertTab(nil)

        XCTAssertEqual(textView.string, "    a\n    b")
    }

    @MainActor
    func testInsertTabIndentsEachSelectedLineWithHardTab() {
        defaults.set(false, forKey: EditorPreferences.tabInsertsSpacesKey)

        let textView = DiffPaneContentTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = "a\nb"
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.utf16.count))
        textView.editorDefaults = defaults

        textView.insertTab(nil)

        XCTAssertEqual(textView.string, "\ta\n\tb")
    }

    @MainActor
    func testInsertTabDoesNotBlockIndentWhenSelectionIsWithinOneLine() {
        defaults.set(true, forKey: EditorPreferences.tabInsertsSpacesKey)
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)

        let textView = DiffPaneContentTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = "ab\ncd"
        textView.setSelectedRange(NSRange(location: 1, length: 1))
        textView.editorDefaults = defaults

        textView.insertTab(nil)

        XCTAssertEqual(textView.string, "a   \ncd")
    }

    @MainActor
    func testInsertTabAndBacktabRoundTripKeepsSameLineCoverage() {
        defaults.set(true, forKey: EditorPreferences.tabInsertsSpacesKey)
        defaults.set(4, forKey: EditorPreferences.tabWidthKey)

        let textView = DiffPaneContentTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = "aa\nbb"
        textView.setSelectedRange(NSRange(location: 1, length: 3))
        textView.editorDefaults = defaults

        textView.insertTab(nil)
        textView.insertBacktab(nil)
        textView.insertTab(nil)
        textView.insertBacktab(nil)

        XCTAssertEqual(textView.string, "aa\nbb")
        let selection = textView.selectedRange()
        XCTAssertEqual(selection.location, 0)
        XCTAssertEqual(selection.length, ("aa\nbb" as NSString).length)
    }
}
