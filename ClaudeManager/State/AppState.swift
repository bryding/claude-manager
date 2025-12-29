import Foundation

@MainActor
@Observable
final class AppState {
    // MARK: - Public Properties

    let context: ExecutionContext
    let stateMachine: ExecutionStateMachine

    // MARK: - Private Services

    private let claudeService: ClaudeCLIService
    private let planService: PlanService
    private let gitService: GitService

    // MARK: - Initialization

    init() {
        let context = ExecutionContext()
        self.context = context

        self.claudeService = ClaudeCLIService()
        self.planService = PlanService()
        self.gitService = GitService()

        self.stateMachine = ExecutionStateMachine(
            context: context,
            claudeService: claudeService,
            planService: planService,
            gitService: gitService
        )
    }
}
