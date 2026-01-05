import XCTest
@testable import ClaudeManager

@MainActor
final class AppStateTests: XCTestCase {
    // MARK: - Initialization

    func testInitCreatesInitialTab() {
        let appState = AppState()

        XCTAssertEqual(appState.tabManager.tabs.count, 1)
        XCTAssertNotNil(appState.activeTab)
    }

    func testInitWithExistingTabManagerDoesNotCreateExtraTab() {
        let tabManager = TabManager()
        tabManager.createTab()

        let appState = AppState(tabManager: tabManager)

        XCTAssertEqual(appState.tabManager.tabs.count, 1)
    }

    func testInitWithEmptyTabManagerCreatesInitialTab() {
        let tabManager = TabManager()

        let appState = AppState(tabManager: tabManager)

        XCTAssertEqual(appState.tabManager.tabs.count, 1)
    }

    func testInitSharesUserPreferences() {
        let preferences = UserPreferences()

        let appState = AppState(userPreferences: preferences)

        XCTAssertTrue(appState.userPreferences === preferences)
    }

    // MARK: - Computed Properties

    func testActiveTabReturnsTabManagerActiveTab() {
        let appState = AppState()
        let expectedTab = appState.tabManager.activeTab

        XCTAssertTrue(appState.activeTab === expectedTab)
    }

    func testActiveTabReturnsNilWhenNoActiveTab() async throws {
        let tabManager = TabManager()
        tabManager.createTab()
        let appState = AppState(tabManager: tabManager)

        if let tab = tabManager.tabs.first {
            try await tabManager.closeTab(tab)
        }

        XCTAssertNil(appState.activeTab)
    }

    func testContextReturnsActiveTabContext() {
        let appState = AppState()
        let expectedContext = appState.activeTab?.context

        XCTAssertTrue(appState.context === expectedContext)
    }

    func testContextReturnsNilWhenNoActiveTab() async throws {
        let tabManager = TabManager()
        tabManager.createTab()
        let appState = AppState(tabManager: tabManager)

        if let tab = tabManager.tabs.first {
            try await tabManager.closeTab(tab)
        }

        XCTAssertNil(appState.context)
    }

    func testStateMachineReturnsActiveTabStateMachine() {
        let appState = AppState()
        let expectedStateMachine = appState.activeTab?.stateMachine

        XCTAssertTrue(appState.stateMachine === expectedStateMachine)
    }

    func testStateMachineReturnsNilWhenNoActiveTab() async throws {
        let tabManager = TabManager()
        tabManager.createTab()
        let appState = AppState(tabManager: tabManager)

        if let tab = tabManager.tabs.first {
            try await tabManager.closeTab(tab)
        }

        XCTAssertNil(appState.stateMachine)
    }

    // MARK: - Tab Switching

    func testContextUpdatesWhenActiveTabChanges() {
        let appState = AppState()
        let tab1 = appState.tabManager.tabs.first!
        let tab2 = appState.tabManager.createTab()

        appState.tabManager.selectTab(tab1)
        let context1 = appState.context

        appState.tabManager.selectTab(tab2)
        let context2 = appState.context

        XCTAssertTrue(context1 === tab1.context)
        XCTAssertTrue(context2 === tab2.context)
        XCTAssertFalse(context1 === context2)
    }

    func testStateMachineUpdatesWhenActiveTabChanges() {
        let appState = AppState()
        let tab1 = appState.tabManager.tabs.first!
        let tab2 = appState.tabManager.createTab()

        appState.tabManager.selectTab(tab1)
        let stateMachine1 = appState.stateMachine

        appState.tabManager.selectTab(tab2)
        let stateMachine2 = appState.stateMachine

        XCTAssertTrue(stateMachine1 === tab1.stateMachine)
        XCTAssertTrue(stateMachine2 === tab2.stateMachine)
        XCTAssertFalse(stateMachine1 === stateMachine2)
    }
}
