import Foundation

// MARK: - Pending Question

struct PendingQuestion: Identifiable, Sendable {
    let id: UUID
    let toolUseId: String
    let question: AskUserQuestionInput.Question
    let timestamp: Date

    init(
        id: UUID = UUID(),
        toolUseId: String,
        question: AskUserQuestionInput.Question,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.toolUseId = toolUseId
        self.question = question
        self.timestamp = timestamp
    }
}

// MARK: - Execution Error

struct ExecutionError: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let phase: ExecutionPhase
    let message: String
    let underlyingError: String?
    let isRecoverable: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        phase: ExecutionPhase,
        message: String,
        underlyingError: String? = nil,
        isRecoverable: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.phase = phase
        self.message = message
        self.underlyingError = underlyingError
        self.isRecoverable = isRecoverable
    }
}

// MARK: - Execution Context

@MainActor
@Observable
final class ExecutionContext {
    // MARK: - Configuration Properties

    var projectPath: URL?
    var featureDescription: String = ""

    // MARK: - Plan State

    var plan: Plan?
    var currentTaskIndex: Int = 0

    // MARK: - Execution State

    var phase: ExecutionPhase = .idle
    var sessionId: String?
    var startTime: Date?

    // MARK: - Logs and Output

    var logs: [LogEntry] = []

    // MARK: - User Interaction

    var pendingQuestion: PendingQuestion?

    // MARK: - Cost Tracking

    var totalCost: Double = 0.0

    // MARK: - Error Tracking

    var errors: [ExecutionError] = []

    // MARK: - Context Usage Tracking

    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0

    // MARK: - Initialization

    init() {}

    // MARK: - Computed Properties

    var currentTask: PlanTask? {
        guard let plan = plan,
              currentTaskIndex >= 0,
              currentTaskIndex < plan.tasks.count else {
            return nil
        }
        return plan.tasks[currentTaskIndex]
    }

    var progress: Double {
        guard let plan = plan, !plan.tasks.isEmpty else {
            return 0.0
        }

        let taskCount = Double(plan.tasks.count)
        let baseProgress = Double(currentTaskIndex) / taskCount
        let taskContribution = phase.progressWeight / taskCount

        return min(baseProgress + taskContribution, 1.0)
    }

    var isRunning: Bool {
        switch phase {
        case .idle, .paused, .completed, .failed:
            return false
        default:
            return true
        }
    }

    var canPause: Bool {
        isRunning && phase != .waitingForUser
    }

    var canResume: Bool {
        phase == .paused
    }

    var canStop: Bool {
        phase != .idle && phase != .completed && phase != .failed
    }

    var hasUnrecoverableError: Bool {
        errors.contains { !$0.isRecoverable }
    }

    var elapsedTime: TimeInterval? {
        guard let startTime = startTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }

    // MARK: - Mutation Methods

    func reset() {
        projectPath = nil
        featureDescription = ""
        plan = nil
        currentTaskIndex = 0
        phase = .idle
        sessionId = nil
        startTime = nil
        logs = []
        pendingQuestion = nil
        totalCost = 0.0
        errors = []
        totalInputTokens = 0
        totalOutputTokens = 0
    }

    func addLog(_ entry: LogEntry) {
        logs.append(entry)
    }

    func addLog(type: LogType, message: String) {
        let entry = LogEntry(
            phase: phase,
            type: type,
            message: message
        )
        logs.append(entry)
    }

    func addError(_ error: ExecutionError) {
        errors.append(error)
    }

    func addError(
        message: String,
        underlyingError: String? = nil,
        isRecoverable: Bool = false
    ) {
        let error = ExecutionError(
            phase: phase,
            message: message,
            underlyingError: underlyingError,
            isRecoverable: isRecoverable
        )
        errors.append(error)
    }

    func updateTaskStatus(_ status: TaskStatus) {
        guard var plan = plan,
              currentTaskIndex >= 0,
              currentTaskIndex < plan.tasks.count else {
            return
        }
        plan.tasks[currentTaskIndex].status = status
        self.plan = plan
    }

    func advanceToNextTask() -> Bool {
        guard let plan = plan else { return false }

        if currentTaskIndex + 1 < plan.tasks.count {
            currentTaskIndex += 1
            return true
        }
        return false
    }

    func accumulateUsage(inputTokens: Int, outputTokens: Int) {
        totalInputTokens += inputTokens
        totalOutputTokens += outputTokens
    }
}
