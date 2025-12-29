import Foundation

@MainActor
@Observable
final class AppState {
    // MARK: - Public Properties

    let context: ExecutionContext
    let stateMachine: ExecutionStateMachine

    // MARK: - Initialization

    init(
        context: ExecutionContext = ExecutionContext(),
        claudeService: any ClaudeCLIServiceProtocol = ClaudeCLIService(),
        planService: PlanService = PlanService(),
        gitService: any GitServiceProtocol = GitService()
    ) {
        self.context = context
        self.stateMachine = ExecutionStateMachine(
            context: context,
            claudeService: claudeService,
            planService: planService,
            gitService: gitService
        )
    }
}
