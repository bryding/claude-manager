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
        let mockWorktreeService = MockWorktreeService()
        let tabManager = TabManager(worktreeService: mockWorktreeService)
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = projectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(projectPath, for: tab2)

        let worktreeInfo = tab2.worktreeInfo!

        try await tabManager.closeTab(tab2)

        XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.count, 1)
        XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.first?.id, worktreeInfo.id)
    }

    func testCloseTabDoesNotRemoveWorktreeWhenNone() async throws {
        let mockWorktreeService = MockWorktreeService()
        let tabManager = TabManager(worktreeService: mockWorktreeService)

        let tab = tabManager.createTab()
        tab.context.projectPath = URL(fileURLWithPath: "/test/project")

        try await tabManager.closeTab(tab)

        XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.count, 0)
    }

    func testCloseTabStopsExecutionBeforeRemovingWorktree() async throws {
        let mockWorktreeService = MockWorktreeService()
        let tabManager = TabManager(worktreeService: mockWorktreeService)
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = projectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(projectPath, for: tab2)
        tab2.context.phase = .executingTask

        try await tabManager.closeTab(tab2)

        XCTAssertTrue(tabManager.tabs.isEmpty || !tabManager.tabs.contains { $0.id == tab2.id })
        XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.count, 1)
    }

    func testCloseTabThrowsWhenWorktreeRemovalFails() async {
        let mockWorktreeService = MockWorktreeService()
        mockWorktreeService.removeWorktreeError = NSError(
            domain: "TestError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Git worktree removal failed"]
        )
        let tabManager = TabManager(worktreeService: mockWorktreeService)
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = projectPath

        let tab2 = tabManager.createTab()
        try? await tabManager.setProjectPath(projectPath, for: tab2)

        do {
            try await tabManager.closeTab(tab2)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(mockWorktreeService.removeWorktreeCalls.count, 1)
        }
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

    // MARK: - Set Project Path

    func testSetProjectPathSetsPathOnTab() async throws {
        let tabManager = TabManager()
        let tab = tabManager.createTab()
        let projectPath = URL(fileURLWithPath: "/test/project")

        try await tabManager.setProjectPath(projectPath, for: tab)

        XCTAssertEqual(tab.context.projectPath, projectPath)
        XCTAssertNil(tab.worktreeInfo)
    }

    func testSetProjectPathCreatesWorktreeForDuplicate() async throws {
        let mockWorktreeService = MockWorktreeService()
        let tabManager = TabManager(worktreeService: mockWorktreeService)
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = projectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(projectPath, for: tab2)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 1)
        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.first, projectPath)
        XCTAssertNotNil(tab2.worktreeInfo)
        XCTAssertEqual(tab2.context.projectPath, tab2.worktreeInfo?.worktreePath)
    }

    func testSetProjectPathDetectsDuplicateByOriginalRepoPath() async throws {
        let mockWorktreeService = MockWorktreeService()
        let tabManager = TabManager(worktreeService: mockWorktreeService)
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab1 = tabManager.createTab()
        tab1.worktreeInfo = WorktreeInfo(
            id: UUID(),
            originalRepoPath: projectPath,
            worktreePath: URL(fileURLWithPath: "/test/project/.worktrees/abc"),
            branchName: "worktree-branch",
            createdAt: Date()
        )

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(projectPath, for: tab2)

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
        let mockWorktreeService = MockWorktreeService()
        let tabManager = TabManager(worktreeService: mockWorktreeService)
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab = tabManager.createTab()
        tab.context.projectPath = projectPath

        try await tabManager.setProjectPath(projectPath, for: tab)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 0)
        XCTAssertEqual(tab.context.projectPath, projectPath)
        XCTAssertNil(tab.worktreeInfo)
    }

    func testSetProjectPathThrowsWhenWorktreeCreationFails() async {
        let mockWorktreeService = MockWorktreeService()
        mockWorktreeService.createWorktreeError = NSError(
            domain: "TestError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Git worktree failed"]
        )
        let tabManager = TabManager(worktreeService: mockWorktreeService)
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = projectPath

        let tab2 = tabManager.createTab()

        do {
            try await tabManager.setProjectPath(projectPath, for: tab2)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNil(tab2.worktreeInfo)
        }
    }

    func testCreateTabWithProjectPathCreatesWorktreeForDuplicate() async throws {
        let mockWorktreeService = MockWorktreeService()
        let tabManager = TabManager(worktreeService: mockWorktreeService)
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = projectPath

        let tab2 = try await tabManager.createTab(projectPath: projectPath)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 1)
        XCTAssertNotNil(tab2.worktreeInfo)
        XCTAssertEqual(tab2.worktreeInfo?.originalRepoPath, projectPath)
    }

    func testMultipleTabsWithSameProjectEachGetWorktree() async throws {
        let mockWorktreeService = MockWorktreeService()
        let tabManager = TabManager(worktreeService: mockWorktreeService)
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = projectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(projectPath, for: tab2)

        let tab3 = tabManager.createTab()
        try await tabManager.setProjectPath(projectPath, for: tab3)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 2)
        XCTAssertNil(tab1.worktreeInfo)
        XCTAssertNotNil(tab2.worktreeInfo)
        XCTAssertNotNil(tab3.worktreeInfo)
        XCTAssertNotEqual(tab2.worktreeInfo?.id, tab3.worktreeInfo?.id)
    }

    func testSetProjectPathWorktreeInfoHasCorrectOriginalPath() async throws {
        let mockWorktreeService = MockWorktreeService()
        let tabManager = TabManager(worktreeService: mockWorktreeService)
        let projectPath = URL(fileURLWithPath: "/test/project")

        let tab1 = tabManager.createTab()
        tab1.context.projectPath = projectPath

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(projectPath, for: tab2)

        XCTAssertEqual(tab2.worktreeInfo?.originalRepoPath, projectPath)
    }

    func testSetProjectPathWithDifferentPathsNoDuplicateDetection() async throws {
        let mockWorktreeService = MockWorktreeService()
        let tabManager = TabManager(worktreeService: mockWorktreeService)

        let tab1 = tabManager.createTab()
        try await tabManager.setProjectPath(URL(fileURLWithPath: "/project/a"), for: tab1)

        let tab2 = tabManager.createTab()
        try await tabManager.setProjectPath(URL(fileURLWithPath: "/project/b"), for: tab2)

        XCTAssertEqual(mockWorktreeService.createWorktreeCalls.count, 0)
        XCTAssertNil(tab1.worktreeInfo)
        XCTAssertNil(tab2.worktreeInfo)
    }
}
