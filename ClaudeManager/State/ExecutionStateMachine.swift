import Foundation

// MARK: - Execution State Machine Error

enum ExecutionStateMachineError: Error, LocalizedError {
    case noProjectPath
    case emptyFeatureDescription
    case notPaused
    case noSessionId
    case noPlan
    case noTasksInPlan
    case phaseExecutionFailed(ExecutionPhase, Error)

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
        case .noPlan:
            return "No plan available after plan generation"
        case .noTasksInPlan:
            return "Plan contains no tasks to execute"
        case .phaseExecutionFailed(let phase, let error):
            return "Phase \(phase.rawValue) failed: \(error.localizedDescription)"
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

    private func handlePhaseError(_ error: Error) {
        context.addError(
            message: "Execution failed during \(context.phase.rawValue)",
            underlyingError: error.localizedDescription,
            isRecoverable: false
        )
        context.addLog(type: .error, message: "Phase failed: \(error.localizedDescription)")
        markCurrentTaskFailed()
        context.phase = .failed
    }

    // MARK: - Main Loop

    private func runLoop() async {
        while !context.phase.isTerminal && !shouldStop && !isPaused {
            if context.phase == .waitingForUser {
                break
            }

            do {
                try await executeCurrentPhase()
            } catch {
                handlePhaseError(error)
                return
            }

            if !shouldStop && !isPaused && context.phase != .waitingForUser && !context.phase.isTerminal {
                transitionToNextPhase()
            }
        }
    }

    // MARK: - Phase Execution

    private func executeCurrentPhase() async throws {
        context.addLog(type: .info, message: "Executing phase: \(context.phase.rawValue)")

        switch context.phase {
        case .idle:
            break

        case .generatingInitialPlan:
            try await generateInitialPlan()

        case .rewritingPlan:
            try await rewritePlanToFormat()

        case .executingTask:
            markCurrentTaskInProgress()
            try await executeCurrentTask()

        case .committingImplementation:
            try await commitChanges(message: commitMessageForImplementation())

        case .reviewingCode:
            try await runCodeReview()

        case .committingReview:
            try await commitChanges(message: commitMessageForReview())

        case .writingTests:
            try await writeTests()

        case .committingTests:
            try await commitChanges(message: commitMessageForTests())

        case .clearingContext:
            try await clearContext()

        case .waitingForUser, .paused, .completed, .failed:
            break
        }
    }

    // MARK: - Phase Transitions

    private func transitionToNextPhase() {
        let previousPhase = context.phase

        switch context.phase {
        case .idle:
            break

        case .generatingInitialPlan:
            context.phase = .rewritingPlan

        case .rewritingPlan:
            if let plan = context.plan, !plan.tasks.isEmpty {
                context.currentTaskIndex = 0
                context.phase = .executingTask
            } else {
                context.addError(message: "No tasks found in plan", isRecoverable: false)
                context.phase = .failed
            }

        case .executingTask:
            markCurrentTaskCompleted()
            context.phase = .committingImplementation

        case .committingImplementation:
            context.phase = .reviewingCode

        case .reviewingCode:
            context.phase = .committingReview

        case .committingReview:
            if shouldWriteTests() {
                context.phase = .writingTests
            } else {
                context.phase = .clearingContext
            }

        case .writingTests:
            context.phase = .committingTests

        case .committingTests:
            context.phase = .clearingContext

        case .clearingContext:
            advanceToNextTaskOrComplete()

        case .waitingForUser, .paused, .completed, .failed:
            break
        }

        if context.phase != previousPhase {
            context.addLog(type: .info, message: "Transitioned to phase: \(context.phase.rawValue)")
        }
    }

    private func advanceToNextTaskOrComplete() {
        if context.advanceToNextTask() {
            context.addLog(
                type: .info,
                message: "Moving to task \(context.currentTaskIndex + 1): \(context.currentTask?.title ?? "Unknown")"
            )
            context.phase = .executingTask
        } else {
            context.addLog(type: .info, message: "All tasks completed")
            context.phase = .completed
        }
    }

    // MARK: - Test Heuristics

    private func shouldWriteTests() -> Bool {
        guard let task = context.currentTask else {
            return false
        }

        let uiKeywords = [
            "view", "ui", "layout", "animation", "style", "color", "font",
            "icon", "image", "button", "label", "text", "visual", "display",
            "indicator", "sheet", "modal", "navigation", "sidebar"
        ]

        let titleLower = task.title.lowercased()
        let descriptionLower = task.description.lowercased()

        for keyword in uiKeywords {
            if titleLower.contains(keyword) || descriptionLower.contains(keyword) {
                context.addLog(type: .info, message: "Skipping tests for UI-related task: \(task.title)")
                return false
            }
        }

        return true
    }

    // MARK: - Task Status Helpers

    private func markCurrentTaskInProgress() {
        context.updateTaskStatus(.inProgress)
    }

    private func markCurrentTaskCompleted() {
        context.updateTaskStatus(.completed)
    }

    private func markCurrentTaskFailed() {
        context.updateTaskStatus(.failed)
    }

    // MARK: - Commit Message Helpers

    private func commitMessageForImplementation() -> String {
        guard let task = context.currentTask else {
            return "Implementation commit"
        }
        return "feat: implement \(task.title)"
    }

    private func commitMessageForReview() -> String {
        guard let task = context.currentTask else {
            return "Code review fixes"
        }
        return "refactor: code review fixes for \(task.title)"
    }

    private func commitMessageForTests() -> String {
        guard let task = context.currentTask else {
            return "Add tests"
        }
        return "test: add tests for \(task.title)"
    }

    // MARK: - Phase Handlers (Placeholders for Task 14)

    private func generateInitialPlan() async throws {
        context.addLog(type: .info, message: "Generating initial plan...")
    }

    private func rewritePlanToFormat() async throws {
        context.addLog(type: .info, message: "Rewriting plan to task format...")
    }

    private func executeCurrentTask() async throws {
        guard let task = context.currentTask else { return }
        context.addLog(type: .info, message: "Executing task: \(task.title)")
    }

    private func runCodeReview() async throws {
        context.addLog(type: .info, message: "Running code review...")
    }

    private func writeTests() async throws {
        context.addLog(type: .info, message: "Writing tests...")
    }

    private func commitChanges(message: String) async throws {
        context.addLog(type: .info, message: "Committing: \(message)")
    }

    private func clearContext() async throws {
        context.sessionId = nil
        context.addLog(type: .info, message: "Context cleared for next task")
    }
}
