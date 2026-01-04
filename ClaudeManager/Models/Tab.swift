import Foundation

// MARK: - Tab

@MainActor
@Observable
final class Tab: Identifiable {
    // MARK: - Properties

    let id: UUID
    var label: String
    let context: ExecutionContext
    let stateMachine: ExecutionStateMachine
    var worktreeInfo: WorktreeInfo?

    // MARK: - Computed Properties

    var effectiveProjectPath: URL? {
        worktreeInfo?.worktreePath ?? context.projectPath
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        label: String,
        context: ExecutionContext,
        stateMachine: ExecutionStateMachine,
        worktreeInfo: WorktreeInfo? = nil
    ) {
        self.id = id
        self.label = label
        self.context = context
        self.stateMachine = stateMachine
        self.worktreeInfo = worktreeInfo
    }

    // MARK: - Factory Methods

    static func create(
        label: String = "New Tab",
        claudeService: (any ClaudeCLIServiceProtocol)? = nil,
        planService: PlanService? = nil,
        gitService: (any GitServiceProtocol)? = nil,
        buildTestService: (any BuildTestServiceProtocol)? = nil,
        userPreferences: UserPreferences,
        worktreeInfo: WorktreeInfo? = nil
    ) -> Tab {
        let context = ExecutionContext()
        let stateMachine = ExecutionStateMachine(
            context: context,
            claudeService: claudeService ?? ClaudeCLIService(),
            planService: planService ?? PlanService(),
            gitService: gitService ?? GitService(),
            buildTestService: buildTestService ?? BuildTestService(),
            userPreferences: userPreferences
        )

        return Tab(
            label: label,
            context: context,
            stateMachine: stateMachine,
            worktreeInfo: worktreeInfo
        )
    }
}
