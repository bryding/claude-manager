import Foundation

@MainActor
@Observable
final class AppState {
    // MARK: - Properties

    let tabManager: TabManager
    let userPreferences: UserPreferences

    // MARK: - Computed Properties (backward compatibility)

    var activeTab: Tab? {
        tabManager.activeTab
    }

    var context: ExecutionContext? {
        activeTab?.context
    }

    var stateMachine: ExecutionStateMachine? {
        activeTab?.stateMachine
    }

    // MARK: - Initialization

    init(
        tabManager: TabManager? = nil,
        userPreferences: UserPreferences? = nil,
        createInitialTab: Bool = true
    ) {
        let resolvedPreferences = userPreferences ?? UserPreferences()
        self.userPreferences = resolvedPreferences
        self.tabManager = tabManager ?? TabManager(userPreferences: resolvedPreferences)

        // Create initial tab if none exist and flag is set
        if createInitialTab && self.tabManager.tabs.isEmpty {
            self.tabManager.createTab()
        }
    }

    // MARK: - Factory Methods

    static func forUITesting(scenario: TestScenario) -> AppState {
        let userPreferences = UserPreferences()
        let tabManager = TabManager(userPreferences: userPreferences)

        let mockClaudeService = MockClaudeCLIServiceForUITests(scenario: scenario)

        let tab = Tab.create(
            label: "Test Tab",
            claudeService: mockClaudeService,
            userPreferences: userPreferences
        )

        tabManager.insertTab(tab)
        tabManager.activeTabId = tab.id

        configureTabForScenario(tab, scenario: scenario)

        return AppState(
            tabManager: tabManager,
            userPreferences: userPreferences,
            createInitialTab: false
        )
    }

    private static func configureTabForScenario(_ tab: Tab, scenario: TestScenario) {
        let context = tab.context
        let mockProjectPath = URL(fileURLWithPath: "/mock/project/path")

        switch scenario {
        case .idle:
            break

        case .setupWithProject:
            context.projectPath = mockProjectPath

        case .executingTask:
            configureActiveExecution(context, projectPath: mockProjectPath)
            context.phase = .executingTask

        case .waitingForUserQuestion:
            configureActiveExecution(context, projectPath: mockProjectPath)
            context.phase = .waitingForUser
            context.pendingQuestion = makeMockPendingQuestion()

        case .completed:
            configureActiveExecution(context, projectPath: mockProjectPath, allTasksCompleted: true)
            context.phase = .completed
            context.startTime = Date().addingTimeInterval(-60)
            context.totalCost = 0.25

        case .failed:
            configureActiveExecution(context, projectPath: mockProjectPath)
            context.phase = .failed
            context.startTime = Date().addingTimeInterval(-30)
            context.currentTaskIndex = 1
            context.addError(
                message: "Mock error for UI testing",
                underlyingError: "Simulated failure",
                isRecoverable: false
            )
        }
    }

    private static func configureActiveExecution(
        _ context: ExecutionContext,
        projectPath: URL,
        allTasksCompleted: Bool = false
    ) {
        context.projectPath = projectPath
        context.featureDescription = "Mock feature for UI testing"
        context.startTime = Date()
        context.plan = makeMockPlan(allCompleted: allTasksCompleted)
        context.currentTaskIndex = 0
    }

    private static func makeMockPlan(allCompleted: Bool = false) -> Plan {
        let tasks = [
            PlanTask(
                number: 1,
                title: "Implement core feature",
                description: "Add the main functionality",
                status: allCompleted ? .completed : .inProgress
            ),
            PlanTask(
                number: 2,
                title: "Add unit tests",
                description: "Write tests for the new feature",
                status: allCompleted ? .completed : .pending
            ),
            PlanTask(
                number: 3,
                title: "Update documentation",
                description: "Document the new feature",
                status: allCompleted ? .completed : .pending
            ),
        ]
        return Plan(rawText: "# Mock Plan\n\nThis is a mock plan for UI testing.", tasks: tasks)
    }

    private static func makeMockPendingQuestion() -> PendingQuestion {
        let question = AskUserQuestionInput.Question(
            question: "Which implementation approach would you prefer?",
            header: "Approach",
            options: [
                AskUserQuestionInput.Option(label: "Option A", description: "A simple implementation"),
                AskUserQuestionInput.Option(label: "Option B", description: "A more complex implementation"),
            ],
            multiSelect: false
        )
        return PendingQuestion(
            toolUseId: "mock-tool-use-id",
            question: question
        )
    }
}
