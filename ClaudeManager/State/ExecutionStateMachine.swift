import Foundation

// MARK: - Execution State Machine Error

enum ExecutionStateMachineError: Error, LocalizedError {
    case noProjectPath
    case emptyFeatureDescription
    case notPaused
    case noSessionId

    var errorDescription: String? {
        switch self {
        case .noProjectPath:
            return "No project path selected"
        case .emptyFeatureDescription:
            return "Feature description cannot be empty"
        case .notPaused:
            return "Cannot resume: execution is not paused"
        case .noSessionId:
            return "Cannot answer question: no active session"
        }
    }
}

// MARK: - Execution State Machine

@MainActor
final class ExecutionStateMachine {
    // MARK: - Dependencies

    let context: ExecutionContext
    let claudeService: ClaudeCLIService
    let planService: PlanService
    let gitService: GitService

    // MARK: - Private State

    private var isPaused = false
    private var shouldStop = false
    private var phaseBeforePause: ExecutionPhase?

    // MARK: - Initialization

    init(
        context: ExecutionContext,
        claudeService: ClaudeCLIService,
        planService: PlanService,
        gitService: GitService
    ) {
        self.context = context
        self.claudeService = claudeService
        self.planService = planService
        self.gitService = gitService
    }

    // MARK: - Control Methods

    func start() async throws {
        guard context.projectPath != nil else {
            throw ExecutionStateMachineError.noProjectPath
        }

        guard !context.featureDescription.isEmpty else {
            throw ExecutionStateMachineError.emptyFeatureDescription
        }

        resetState()
        context.startTime = Date()
        context.phase = .generatingInitialPlan
        context.addLog(type: .info, message: "Starting execution loop")

        await runLoop()
    }

    func pause() {
        guard context.canPause else { return }

        isPaused = true
        phaseBeforePause = context.phase
        claudeService.interrupt()

        context.phase = .paused
        context.addLog(type: .info, message: "Execution paused")
    }

    func resume() async throws {
        guard context.phase == .paused else {
            throw ExecutionStateMachineError.notPaused
        }

        isPaused = false

        if let previousPhase = phaseBeforePause {
            context.phase = previousPhase
            phaseBeforePause = nil
        }

        context.addLog(type: .info, message: "Execution resumed")

        await runLoop()
    }

    func stop() {
        guard context.canStop else { return }

        shouldStop = true
        claudeService.terminate()

        context.phase = .failed
        context.addLog(type: .info, message: "Execution stopped by user")
        context.addError(
            message: "Execution stopped by user",
            isRecoverable: false
        )
    }

    func answerQuestion(_ answer: String) async throws {
        guard context.pendingQuestion != nil else { return }
        guard context.sessionId != nil else {
            throw ExecutionStateMachineError.noSessionId
        }

        context.pendingQuestion = nil
        context.addLog(type: .info, message: "User answered: \(answer)")

        await runLoop()
    }

    // MARK: - Private Methods

    private func resetState() {
        isPaused = false
        shouldStop = false
        phaseBeforePause = nil
    }

    // MARK: - Main Loop (Placeholder for Task 13)

    private func runLoop() async {
        while !context.phase.isTerminal && !shouldStop && !isPaused {
            if context.phase == .waitingForUser {
                break
            }

            await executeCurrentPhase()

            if !shouldStop && !isPaused && context.phase != .waitingForUser {
                transitionToNextPhase()
            }
        }
    }

    // MARK: - Phase Execution (Placeholder for Task 14)

    private func executeCurrentPhase() async {
        // Placeholder - will be implemented in Task 14
        context.addLog(type: .info, message: "Executing phase: \(context.phase.rawValue)")
    }

    // MARK: - Phase Transitions (Placeholder for Task 13)

    private func transitionToNextPhase() {
        // Placeholder - will be implemented in Task 13
    }
}
