import XCTest
@testable import ClaudeManager

@MainActor
final class TabManagerTests: XCTestCase {
    // MARK: - Test Helpers

    private func makeTabManager(
        worktreeService: MockWorktreeService = MockWorktreeService()
    ) -> (TabManager, MockWorktreeService) {
        let tabManager = TabManager(worktreeService: worktreeService)
        return (tabManager, worktreeService)
    }

    private var testProjectPath: URL {
        URL(fileURLWithPath: "/test/project")
    }

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

    func testCreateTabWithProjectPathSetsContextProjectPath() async throws {
        let tabManager = TabManager()
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab = try await tabManager.createTab(projectPath: projectPath)

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

    func testCloseTabRemovesTab() async throws {
        let tabManager = TabManager()
        let tab = tabManager.createTab()

        try await tabManager.closeTab(tab)

        XCTAssertTrue(tabManager.tabs.isEmpty)
    }

    func testCloseActiveTabSelectsNextTab() async throws {
        let tabManager = TabManager()
        _ = tabManager.createTab()
        let tab2 = tabManager.createTab()
        let tab3 = tabManager.createTab()

        tabManager.selectTab(tab2)
        try await tabManager.closeTab(tab2)

        XCTAssertEqual(tabManager.tabs.count, 2)
        XCTAssertEqual(tabManager.activeTabId, tab3.id)
    }

    func testCloseLastTabSelectsPreviousTab() async throws {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        let tab2 = tabManager.createTab()

        try await tabManager.closeTab(tab2)

        XCTAssertEqual(tabManager.activeTabId, tab1.id)
    }

    func testCloseOnlyTabClearsActiveTab() async throws {
        let tabManager = TabManager()
        let tab = tabManager.createTab()

        try await tabManager.closeTab(tab)

        XCTAssertNil(tabManager.activeTabId)
        XCTAssertNil(tabManager.activeTab)
    }

    func testCloseNonActiveTabPreservesActiveTab() async throws {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        _ = tabManager.createTab()
        let tab3 = tabManager.createTab()

        tabManager.selectTab(tab3)
        try await tabManager.closeTab(tab1)

        XCTAssertEqual(tabManager.activeTabId, tab3.id)
        XCTAssertEqual(tabManager.tabs.count, 2)
    }

    func testCloseNonExistentTabDoesNothing() async throws {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        let orphanTab = Tab.create(userPreferences: UserPreferences())

        try await tabManager.closeTab(orphanTab)

        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.activeTabId, tab1.id)
    }

    func testCloseTabRemovesWorktree() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab2)

        let worktreeInfo = try XCTUnwrap(tab2.worktreeInfo)

        try await tabManager.closeTab(tab2)

        XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.count, 1)
        XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.first?.id, worktreeInfo.id)
    }

    func testCloseTabDoesNotRemoveWorktreeWhenNone() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab = tabManager.createTab()
        tab.context.projectPath = testProjectPath

        try await tabManager.closeTab(tab)

        XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.count, 0)
    }

    func testCloseTabStopsExecutionBeforeRemovingWorktree() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab2)
        tab2.context.phase = .executingTask

        try await tabManager.closeTab(tab2)

        XCTAssertFalse(tabManager.tabs.contains { $0.id == tab2.id })
        XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.count, 1)
    }

    func testCloseTabThrowsWhenWorktreeRemovalFails() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()
        mockWorktreeService.removeWorktreeError = NSError(
            domain: "TestError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Git worktree removal failed"]
        )

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab2)

        do {
            try await tabManager.closeTab(tab2)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.count, 1)
        }
    }

    func testCloseTabDoesNotStopExecutionWhenIdle() async throws {
        let (tabManager, _) = makeTabManager()

        let tab = tabManager.createTab()
        tab.context.phase = .idle

        try await tabManager.closeTab(tab)

        XCTAssertTrue(tabManager.tabs.isEmpty)
        XCTAssertEqual(tab.context.phase, .idle)
    }

    func testCloseTabPassesCorrectWorktreeInfoToService() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab2)

        let expectedWorktreeInfo = try XCTUnwrap(tab2.worktreeInfo)

        try await tabManager.closeTab(tab2)

        let removedWorktree = try XCTUnwrap(mockWorktreeService.removeWorktreeCalls.first)
        XCTAssertEqual(removedWorktree.id, expectedWorktreeInfo.id)
        XCTAssertEqual(removedWorktree.originalRepoPath, expectedWorktreeInfo.originalRepoPath)
        XCTAssertEqual(removedWorktree.worktreePath, expectedWorktreeInfo.worktreePath)
        XCTAssertEqual(removedWorktree.branchName, expectedWorktreeInfo.branchName)
    }

    func testCloseMultipleTabsWithWorktreesRemovesAll() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab2)

        let tab3 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab3)

        try await tabManager.closeTab(tab2)
        try await tabManager.closeTab(tab3)

        XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.count, 2)
        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.tabs.first?.id, tab1.id)
    }

    func testCloseTabWithWorktreeDoesNotAffectOtherTabs() async throws {
        let (tabManager, _) = makeTabManager()

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab2)

        let tab3 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab3)

        let tab3WorktreeInfo = try XCTUnwrap(tab3.worktreeInfo)

        try await tabManager.closeTab(tab2)

        XCTAssertNotNil(tab3.worktreeInfo)
        XCTAssertEqual(tab3.worktreeInfo?.id, tab3WorktreeInfo.id)
        XCTAssertEqual(tabManager.tabs.count, 2)
    }

    // MARK: - Select Tab

    func testSelectNextTabWithNoTabsDoesNothing() {
        let tabManager = TabManager()

        tabManager.selectNextTab()

        XCTAssertNil(tabManager.activeTabId)
    }

    func testSelectNextTabWithNoActiveTabSelectsFirst() {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        _ = tabManager.createTab()
        tabManager.activeTabId = nil

        tabManager.selectNextTab()

        XCTAssertEqual(tabManager.activeTabId, tab1.id)
    }

    func testSelectNextTabSelectsNextTab() {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        let tab2 = tabManager.createTab()
        _ = tabManager.createTab()
        tabManager.selectTab(tab1)

        tabManager.selectNextTab()

        XCTAssertEqual(tabManager.activeTabId, tab2.id)
    }

    func testSelectNextTabWrapsToFirst() {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        _ = tabManager.createTab()
        let tab3 = tabManager.createTab()
        tabManager.selectTab(tab3)

        tabManager.selectNextTab()

        XCTAssertEqual(tabManager.activeTabId, tab1.id)
    }

    func testSelectPreviousTabWithNoTabsDoesNothing() {
        let tabManager = TabManager()

        tabManager.selectPreviousTab()

        XCTAssertNil(tabManager.activeTabId)
    }

    func testSelectPreviousTabWithNoActiveTabSelectsLast() {
        let tabManager = TabManager()
        _ = tabManager.createTab()
        let tab2 = tabManager.createTab()
        tabManager.activeTabId = nil

        tabManager.selectPreviousTab()

        XCTAssertEqual(tabManager.activeTabId, tab2.id)
    }

    func testSelectPreviousTabSelectsPreviousTab() {
        let tabManager = TabManager()
        _ = tabManager.createTab()
        let tab2 = tabManager.createTab()
        let tab3 = tabManager.createTab()
        tabManager.selectTab(tab3)

        tabManager.selectPreviousTab()

        XCTAssertEqual(tabManager.activeTabId, tab2.id)
    }

    func testSelectPreviousTabWrapsToLast() {
        let tabManager = TabManager()
        let tab1 = tabManager.createTab()
        _ = tabManager.createTab()
        let tab3 = tabManager.createTab()
        tabManager.selectTab(tab1)

        tabManager.selectPreviousTab()

        XCTAssertEqual(tabManager.activeTabId, tab3.id)
    }

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

    // MARK: - Set Project Path

    func testSetProjectPathSetsPathOnTab() async throws {
        let tabManager = TabManager()
        let tab = tabManager.createTab()

        try await tabManager.setProjectPath(testProjectPath, for: tab)

        XCTAssertEqual(tab.context.projectPath, testProjectPath)
        XCTAssertNil(tab.worktreeInfo)
    }

    func testSetProjectPathCreatesWorktreeForDuplicate() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab2)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 1)
        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.first, testProjectPath)
        XCTAssertNotNil(tab2.worktreeInfo)
        XCTAssertEqual(tab2.context.projectPath, tab2.worktreeInfo?.worktreePath)
    }

    func testSetProjectPathDetectsDuplicateByOriginalRepoPath() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab1 = tabManager.createTab()
        tab1.worktreeInfo = WorktreeInfo(
            id: UUID(),
            originalRepoPath: testProjectPath,
            worktreePath: URL(fileURLWithPath: "/test/project/.worktrees/abc"),
            branchName: "worktree-branch",
            createdAt: Date()
        )

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab2)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 1)
        XCTAssertNotNil(tab2.worktreeInfo)
    }

    func testSetProjectPathClearsWorktreeInfoWhenNotDuplicate() async throws {
        let tabManager = TabManager()
        let tab = tabManager.createTab()
        tab.worktreeInfo = WorktreeInfo(
            id: UUID(),
            originalRepoPath: URL(fileURLWithPath: "/old/project"),
            worktreePath: URL(fileURLWithPath: "/old/project/.worktrees/abc"),
            branchName: "old-branch",
            createdAt: Date()
        )

        let newPath = URL(fileURLWithPath: "/new/project")
        try await tabManager.setProjectPath(newPath, for: tab)

        XCTAssertEqual(tab.context.projectPath, newPath)
        XCTAssertNil(tab.worktreeInfo)
    }

    func testSetProjectPathDoesNotTreatSameTabAsDuplicate() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab = tabManager.createTab()
        tab.context.projectPath = testProjectPath

        try await tabManager.setProjectPath(testProjectPath, for: tab)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 0)
        XCTAssertEqual(tab.context.projectPath, testProjectPath)
        XCTAssertNil(tab.worktreeInfo)
    }

    func testSetProjectPathThrowsWhenWorktreeCreationFails() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()
        mockWorktreeService.createWorktreeError = NSError(
            domain: "TestError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Git worktree failed"]
        )

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = tabManager.createTab()

        do {
            try await tabManager.setProjectPath(testProjectPath, for: tab2)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNil(tab2.worktreeInfo)
        }
    }

    func testCreateTabWithProjectPathCreatesWorktreeForDuplicate() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = try await tabManager.createTab(projectPath: testProjectPath)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 1)
        XCTAssertNotNil(tab2.worktreeInfo)
        XCTAssertEqual(tab2.worktreeInfo?.originalRepoPath, testProjectPath)
    }

    func testMultipleTabsWithSameProjectEachGetWorktree() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab2)

        let tab3 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab3)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 2)
        XCTAssertNil(tab1.worktreeInfo)
        XCTAssertNotNil(tab2.worktreeInfo)
        XCTAssertNotNil(tab3.worktreeInfo)
        XCTAssertNotEqual(tab2.worktreeInfo?.id, tab3.worktreeInfo?.id)
    }

    func testSetProjectPathWorktreeInfoHasCorrectOriginalPath() async throws {
        let (tabManager, _) = makeTabManager()

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = testProjectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(testProjectPath, for: tab2)

        XCTAssertEqual(tab2.worktreeInfo?.originalRepoPath, testProjectPath)
    }

    func testSetProjectPathWithDifferentPathsNoDuplicateDetection() async throws {
        let (tabManager, mockWorktreeService) = makeTabManager()

        let tab1 = tabManager.createTab()
        try await tabManager.setProjectPath(URL(fileURLWithPath: "/project/a"), for: tab1)

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(URL(fileURLWithPath: "/project/b"), for: tab2)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 0)
        XCTAssertNil(tab1.worktreeInfo)
        XCTAssertNil(tab2.worktreeInfo)
    }
}
