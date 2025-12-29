import Foundation

@MainActor
@Observable
final class AppState {
    // MARK: - Public Properties

    let context: ExecutionContext
    let stateMachine: ExecutionStateMachine

    // MARK: - Initialization

    init(
        context: ExecutionContext? = nil,
        claudeService: (any ClaudeCLIServiceProtocol)? = nil,
        planService: PlanService? = nil,
        gitService: (any GitServiceProtocol)? = nil
    ) {
        let resolvedContext = context ?? ExecutionContext()
        self.context = resolvedContext
        self.stateMachine = ExecutionStateMachine(
            context: resolvedContext,
            claudeService: claudeService ?? ClaudeCLIService(),
            planService: planService ?? PlanService(),
            gitService: gitService ?? GitService()
        )
    }
}
