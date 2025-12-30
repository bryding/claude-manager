import Foundation

@MainActor
@Observable
final class AppState {
    // MARK: - Public Properties

    let context: ExecutionContext
    let stateMachine: ExecutionStateMachine
    let userPreferences: UserPreferences

    // MARK: - Initialization

    init(
        context: ExecutionContext? = nil,
        claudeService: (any ClaudeCLIServiceProtocol)? = nil,
        planService: PlanService? = nil,
        gitService: (any GitServiceProtocol)? = nil,
        buildTestService: (any BuildTestServiceProtocol)? = nil,
        userPreferences: UserPreferences? = nil
    ) {
        let resolvedContext = context ?? ExecutionContext()
        self.context = resolvedContext
        self.userPreferences = userPreferences ?? UserPreferences()
        self.stateMachine = ExecutionStateMachine(
            context: resolvedContext,
            claudeService: claudeService ?? ClaudeCLIService(),
            planService: planService ?? PlanService(),
            gitService: gitService ?? GitService(),
            buildTestService: buildTestService ?? BuildTestService(),
            userPreferences: self.userPreferences
        )
    }
}
