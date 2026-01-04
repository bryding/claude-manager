import XCTest
@testable import ClaudeManager

@MainActor
final class TabManagerTests: XCTestCase {
    // MARK: - Initialization

    func testInitializesWithEmptyTabs() {
        let tabManager = TabManager()

        XCTAssertTrue(tabManager.tabs.isEmpty)
        XCTAssertNil(tabManager.activeTabId)
        XCTAssertNil(tabManager.activeTab)
    }

    func testInitializesWithInjectedDependencies() {
        let preferences = UserPreferences()
        let worktreeService = MockWorktreeService()

        let tabManager = TabManager(
            userPreferences: preferences,
            worktreeService: worktreeService
        )

        XCTAssertTrue(tabManager.tabs.isEmpty)
    }

    // MARK: - Create Tab

    func testCreateTabAddsNewTab() {
        let tabManager = TabManager()

        let tab = tabManager.createTab()

        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.tabs.first?.id, tab.id)
    }

    func testCreateTabSetsActiveTab() {
        let tabManager = TabManager()

        let tab = tabManager.createTab()

        XCTAssertEqual(tabManager.activeTabId, tab.id)
        XCTAssertEqual(tabManager.activeTab?.id, tab.id)
    }

    func testCreateTabWithProjectPathSetsContextProjectPath() {
        let tabManager = TabManager()
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab = tabManager.createTab(projectPath: projectPath)

        XCTAssertEqual(tab.context.projectPath, projectPath)
    }

    func testCreateMultipleTabsSelectsLastCreated() {
        let tabManager = TabManager()

        _ = tabManager.createTab()
        let tab2 = tabManager.createTab()
        _ = tabManager.createTab()
        let tab4 = tabManager.createTab()

        XCTAssertEqual(tabManager.tabs.count, 4)
        XCTAssertEqual(tabManager.activeTabId, tab4.id)
        XCTAssertEqual(tabManager.tabs[1].id, tab2.id)
    }

    // MARK: - Close Tab

    func testCloseTabRemovesTab() {
        let tabManager = TabManager()
        let tab = tabManager.createTab()

        tabManager.closeTab(tab)

        XCTAssertTrue(tabManager.tabs.isEmpty)
    }

    func testCloseActiveTabSelectsNextTab() {
        let tabManager = TabManager()
        _ = tabManager.createTab()
        let tab2 = tabManager.createTab()
        let tab3 = tabManager.createTab()

        tabManager.selectTab(tab2)
        tabManager.closeTab(tab2)

        XCTAssertEqual(tabManager.tabs.count, 2)
        XCTAssertEqual(tabManager.activeTabId, tab3.id)
    }

    func testCloseLastTabSelectsPreviousTab() {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        let tab2 = tabManager.createTab()

        tabManager.closeTab(tab2)

        XCTAssertEqual(tabManager.activeTabId, tab1.id)
    }

    func testCloseOnlyTabClearsActiveTab() {
        let tabManager = TabManager()
        let tab = tabManager.createTab()

        tabManager.closeTab(tab)

        XCTAssertNil(tabManager.activeTabId)
        XCTAssertNil(tabManager.activeTab)
    }

    func testCloseNonActiveTabPreservesActiveTab() {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        _ = tabManager.createTab()
        let tab3 = tabManager.createTab()

        tabManager.selectTab(tab3)
        tabManager.closeTab(tab1)

        XCTAssertEqual(tabManager.activeTabId, tab3.id)
        XCTAssertEqual(tabManager.tabs.count, 2)
    }

    func testCloseNonExistentTabDoesNothing() {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        let orphanTab = Tab.create(userPreferences: UserPreferences())

        tabManager.closeTab(orphanTab)

        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.activeTabId, tab1.id)
    }

    // MARK: - Select Tab

    func testSelectTabChangesActiveTab() {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        _ = tabManager.createTab()

        tabManager.selectTab(tab1)

        XCTAssertEqual(tabManager.activeTabId, tab1.id)
    }

    func testSelectNonExistentTabDoesNothing() {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        let orphanTab = Tab.create(userPreferences: UserPreferences())

        tabManager.selectTab(orphanTab)

        XCTAssertEqual(tabManager.activeTabId, tab1.id)
    }

    // MARK: - Active Tab Computed Property

    func testActiveTabReturnsCorrectTab() {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        _ = tabManager.createTab()

        tabManager.selectTab(tab1)

        XCTAssertTrue(tabManager.activeTab === tab1)
    }

    func testActiveTabReturnsNilWhenNoTabs() {
        let tabManager = TabManager()

        XCTAssertNil(tabManager.activeTab)
    }

    func testActiveTabReturnsNilWhenActiveIdInvalid() {
        let tabManager = TabManager()
        _ = tabManager.createTab()
        tabManager.activeTabId = UUID()

        XCTAssertNil(tabManager.activeTab)
    }
}
