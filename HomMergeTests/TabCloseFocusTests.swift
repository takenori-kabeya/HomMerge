import XCTest
@testable import HomMerge

@MainActor
final class TabCloseFocusTests: XCTestCase {
    func testCloseSelectedTabSelectsMostRecentlyUsedTab() {
        let appModel = AppViewModel()
        let tabA = appModel.tabs[0]
        let tabB = appModel.addTab(select: false)
        let tabC = appModel.addTab(select: false)

        appModel.selectTab(tabA.id)
        appModel.selectTab(tabC.id)
        appModel.selectTab(tabB.id)

        appModel.closeTab(tabB.id)

        XCTAssertEqual(appModel.tabs.map(\.id), [tabA.id, tabC.id])
        XCTAssertEqual(appModel.selectedTabID, tabC.id)
    }

    func testCloseSelectedTabFallsBackToLeftNeighborWhenHistoryEmpty() {
        let appModel = AppViewModel()
        let tabA = appModel.tabs[0]
        let tabB = appModel.addTab(select: false)
        let tabC = appModel.addTab(select: false)

        appModel.selectTab(tabC.id)
        appModel.closeTab(tabA.id)

        XCTAssertEqual(appModel.selectedTabID, tabC.id)
        appModel.closeTab(tabC.id)

        XCTAssertEqual(appModel.tabs.map(\.id), [tabB.id])
        XCTAssertEqual(appModel.selectedTabID, tabB.id)
    }

    func testCloseFirstTabFallsBackToRightNeighborWhenHistoryEmpty() {
        let appModel = AppViewModel()
        let tabA = appModel.tabs[0]
        let tabB = appModel.addTab(select: false)

        appModel.closeTab(tabA.id)

        XCTAssertEqual(appModel.tabs.map(\.id), [tabB.id])
        XCTAssertEqual(appModel.selectedTabID, tabB.id)
    }

    func testCloseNonSelectedTabDoesNotChangeSelection() {
        let appModel = AppViewModel()
        let tabA = appModel.tabs[0]
        let tabB = appModel.addTab(select: false)
        let tabC = appModel.addTab(select: false)

        appModel.selectTab(tabA.id)
        appModel.closeTab(tabC.id)

        XCTAssertEqual(appModel.tabs.map(\.id), [tabA.id, tabB.id])
        XCTAssertEqual(appModel.selectedTabID, tabA.id)
    }

    func testCloseSelectedTabsFollowsMRUChain() {
        let appModel = AppViewModel()
        let tabA = appModel.tabs[0]
        let tabB = appModel.addTab(select: false)
        let tabC = appModel.addTab(select: false)

        appModel.selectTab(tabA.id)
        appModel.selectTab(tabB.id)
        appModel.selectTab(tabC.id)

        appModel.closeTab(tabC.id)
        XCTAssertEqual(appModel.selectedTabID, tabB.id)

        appModel.closeTab(tabB.id)
        XCTAssertEqual(appModel.selectedTabID, tabA.id)
        XCTAssertEqual(appModel.tabs.map(\.id), [tabA.id])
    }
}
