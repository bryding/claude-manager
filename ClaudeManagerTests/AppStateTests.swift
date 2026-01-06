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

    // MARK: - forUITesting Factory Method

    func testForUITestingCreatesAppStateWithOneTab() {
        let appState = AppState.forUITesting(scenario: .idle)

        XCTAssertEqual(appState.tabManager.tabs.count, 1)
        XCTAssertNotNil(appState.activeTab)
    }

    func testForUITestingIdleScenarioSetsIdlePhase() {
        let appState = AppState.forUITesting(scenario: .idle)

        XCTAssertEqual(appState.context?.phase, .idle)
        XCTAssertNil(appState.context?.projectPath)
    }

    func testForUITestingSetupWithProjectScenarioSetsProjectPath() {
        let appState = AppState.forUITesting(scenario: .setupWithProject)

        XCTAssertEqual(appState.context?.phase, .idle)
        XCTAssertNotNil(appState.context?.projectPath)
        XCTAssertEqual(appState.context?.projectPath?.path, "/mock/project/path")
    }

    func testForUITestingExecutingTaskScenarioConfiguresActiveExecution() {
        let appState = AppState.forUITesting(scenario: .executingTask)

        XCTAssertEqual(appState.context?.phase, .executingTask)
        XCTAssertNotNil(appState.context?.projectPath)
        XCTAssertEqual(appState.context?.featureDescription, "Mock feature for UI testing")
        XCTAssertNotNil(appState.context?.startTime)
        XCTAssertNotNil(appState.context?.plan)
        XCTAssertEqual(appState.context?.plan?.tasks.count, 3)
        XCTAssertEqual(appState.context?.currentTaskIndex, 0)
    }

    func testForUITestingWaitingForUserQuestionScenarioSetsPendingQuestion() {
        let appState = AppState.forUITesting(scenario: .waitingForUserQuestion)

        XCTAssertEqual(appState.context?.phase, .waitingForUser)
        XCTAssertNotNil(appState.context?.pendingQuestion)
        XCTAssertEqual(appState.context?.pendingQuestion?.question.header, "Approach")
        XCTAssertEqual(appState.context?.pendingQuestion?.question.options.count, 2)
    }

    func testForUITestingCompletedScenarioSetsCompletedState() {
        let appState = AppState.forUITesting(scenario: .completed)

        XCTAssertEqual(appState.context?.phase, .completed)
        XCTAssertEqual(appState.context?.totalCost, 0.25)
        XCTAssertNotNil(appState.context?.plan)

        let allTasksCompleted = appState.context?.plan?.tasks.allSatisfy { $0.status == .completed }
        XCTAssertTrue(allTasksCompleted == true)
    }

    func testForUITestingFailedScenarioSetsErrorState() {
        let appState = AppState.forUITesting(scenario: .failed)

        XCTAssertEqual(appState.context?.phase, .failed)
        XCTAssertEqual(appState.context?.currentTaskIndex, 1)
        XCTAssertEqual(appState.context?.errors.count, 1)
        XCTAssertEqual(appState.context?.errors.first?.message, "Mock error for UI testing")
        XCTAssertEqual(appState.context?.errors.first?.isRecoverable, false)
    }

    func testForUITestingUsesCorrectTabLabel() {
        let appState = AppState.forUITesting(scenario: .idle)

        XCTAssertEqual(appState.activeTab?.label, "Test Tab")
    }

    func testForUITestingAllScenariosCreateValidState() {
        for scenario in TestScenario.allCases {
            let appState = AppState.forUITesting(scenario: scenario)

            XCTAssertEqual(appState.tabManager.tabs.count, 1, "Scenario \(scenario) should have 1 tab")
            XCTAssertNotNil(appState.activeTab, "Scenario \(scenario) should have active tab")
            XCTAssertNotNil(appState.context, "Scenario \(scenario) should have context")
        }
    }
}
