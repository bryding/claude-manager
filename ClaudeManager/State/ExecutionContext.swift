import Foundation

// MARK: - Task Failure Response

enum TaskFailureResponse: String {
    case retry = "Retry"
    case skip = "Skip"
    case stop = "Stop"
}

// MARK: - Pending Task Failure

struct PendingTaskFailure: Identifiable, Sendable {
    let id: UUID
    let taskId: String
    let taskTitle: String
    let error: String

    init(
        id: UUID = UUID(),
        taskId: String,
        taskTitle: String,
        error: String
    ) {
        self.id = id
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.error = error
    }
}

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

// MARK: - Fallback Reason

enum FallbackReason: Sendable, Equatable {
    case timeout
    case commandFailure(String)
    case consecutiveFailures(Int)
    case userToggled

    var displayMessage: String {
        switch self {
        case .timeout:
            return "Command timed out"
        case .commandFailure(let error):
            return "Command failed: \(error)"
        case .consecutiveFailures(let count):
            return "\(count) consecutive failures"
        case .userToggled:
            return "User switched to manual"
        }
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
    var existingPlan: Plan?
    var currentTaskIndex: Int = 0

    // MARK: - Execution State

    var phase: ExecutionPhase = .idle
    var sessionId: String?
    var startTime: Date?

    // MARK: - Logs and Output

    var logs: [LogEntry] = []

    // MARK: - User Interaction

    var pendingQuestion: PendingQuestion?
    var pendingInterviewQuestion: PendingQuestion?
    var questionQueue: [PendingQuestion] = []

    // MARK: - Cost Tracking

    var totalCost: Double = 0.0

    // MARK: - Error Tracking

    var errors: [ExecutionError] = []

    // MARK: - Context Usage Tracking

    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0

    // MARK: - Context Window Management

    var continuationSummary: ContinuationSummary?
    var isHandoffInProgress: Bool = false

    static let contextWindowSize: Int = 200_000
    private static let maxLogEntries: Int = 10_000
    private static let maxErrorEntries: Int = 1_000

    // MARK: - Retry Configuration

    var retryConfiguration: RetryConfiguration = .default
    var currentRetryAttempt: Int = 0

    // MARK: - Autonomous Failure Tracking

    var taskFailureCount: Int = 0
    var autonomousConfig: AutonomousConfiguration = .default

    // MARK: - Command Execution Fallback State

    var isInFallbackMode: Bool = false
    var consecutiveCommandFailures: Int = 0
    var fallbackReason: FallbackReason?
    var autonomousModeOverride: Bool?

    // MARK: - Timeout Configuration

    var timeoutConfiguration: TimeoutConfiguration = .default

    // MARK: - Build/Test Constants

    static let maxBuildFixAttempts: Int = 3
    static let maxTestFixAttempts: Int = 3

    // MARK: - Task Failure State

    var pendingTaskFailure: PendingTaskFailure?

    // MARK: - Build/Test State

    var projectConfiguration: ProjectConfiguration = .default
    var buildAttempts: Int = 0
    var testAttempts: Int = 0
    var lastBuildResult: CommandResult?
    var lastTestResult: CommandResult?

    // MARK: - Interview State

    var interviewSession: InterviewSession?
    var currentInterviewQuestion: String?

    // MARK: - Attached Images

    var attachedImages: [AttachedImage] = []

    // MARK: - UI State

    var showStopConfirmation: Bool = false
    var suggestedManualInput: String = ""

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
        let completedCount = Double(plan.tasks.filter { $0.status == .completed || $0.status == .skipped }.count)
        let inProgressBonus = phase == .executingTask ? 0.5 : 0.0

        return min((completedCount + inProgressBonus) / taskCount, 1.0)
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

    var canStart: Bool {
        phase == .idle
    }

    var hasUnrecoverableError: Bool {
        errors.contains { !$0.isRecoverable }
    }

    var elapsedTime: TimeInterval? {
        guard let startTime = startTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }

    var contextPercentRemaining: Double {
        guard totalInputTokens > 0 else { return 1.0 }
        let used = Double(totalInputTokens) / Double(Self.contextWindowSize)
        return max(0.0, 1.0 - used)
    }

    var contextPercentUsed: Double {
        1.0 - contextPercentRemaining
    }

    var isContextLow: Bool {
        contextPercentRemaining < 0.10
    }

    var isManualInputAvailable: Bool {
        sessionId != nil && !phase.isTerminal && phase != .idle
    }

    var appearsStuck: Bool {
        phase == .conductingInterview
            && pendingQuestion == nil
            && pendingInterviewQuestion == nil
            && interviewSession?.isComplete != true
    }

    var hasQueuedQuestions: Bool {
        !questionQueue.isEmpty
    }

    var hasPendingInterviewQuestion: Bool {
        pendingInterviewQuestion != nil
    }

    var promptContent: PromptContent {
        PromptContent(text: featureDescription, images: attachedImages)
    }

    var effectiveCommandExecutionMode: CommandExecutionMode {
        if let override = autonomousModeOverride {
            return override ? .autonomous : .manual
        }
        if isInFallbackMode {
            return .manual
        }
        return autonomousConfig.commandExecutionMode
    }

    var isAutonomousCommandExecution: Bool {
        effectiveCommandExecutionMode != .manual
    }

    // MARK: - Mutation Methods

    func reset() {
        projectPath = nil
        featureDescription = ""
        plan = nil
        existingPlan = nil
        currentTaskIndex = 0
        phase = .idle
        sessionId = nil
        startTime = nil
        logs = []
        pendingQuestion = nil
        pendingInterviewQuestion = nil
        questionQueue = []
        totalCost = 0.0
        errors = []
        totalInputTokens = 0
        totalOutputTokens = 0
        continuationSummary = nil
        isHandoffInProgress = false
        currentRetryAttempt = 0
        taskFailureCount = 0
        pendingTaskFailure = nil
        showStopConfirmation = false
        suggestedManualInput = ""
        projectConfiguration = .default
        buildAttempts = 0
        testAttempts = 0
        lastBuildResult = nil
        lastTestResult = nil
        interviewSession = nil
        currentInterviewQuestion = nil
        attachedImages = []
        isInFallbackMode = false
        consecutiveCommandFailures = 0
        fallbackReason = nil
        autonomousModeOverride = nil
    }

    func resetForNewFeature() {
        let separatorEntry = LogEntry(
            phase: .idle,
            type: .separator,
            message: "─── New Feature Session ───"
        )
        logs.append(separatorEntry)

        featureDescription = ""
        plan = nil
        existingPlan = nil
        currentTaskIndex = 0
        phase = .idle
        sessionId = nil
        startTime = nil
        pendingQuestion = nil
        pendingInterviewQuestion = nil
        questionQueue = []
        totalCost = 0.0
        errors = []
        totalInputTokens = 0
        totalOutputTokens = 0
        continuationSummary = nil
        isHandoffInProgress = false
        currentRetryAttempt = 0
        taskFailureCount = 0
        pendingTaskFailure = nil
        showStopConfirmation = false
        suggestedManualInput = ""
        buildAttempts = 0
        testAttempts = 0
        lastBuildResult = nil
        lastTestResult = nil
        interviewSession = nil
        currentInterviewQuestion = nil
        attachedImages = []
        isInFallbackMode = false
        consecutiveCommandFailures = 0
        fallbackReason = nil
        autonomousModeOverride = nil
    }

    func resetRetryAttempt() {
        currentRetryAttempt = 0
    }

    func resetTaskFailureCount() {
        taskFailureCount = 0
    }

    func resetBuildAttempts() {
        buildAttempts = 0
    }

    func resetTestAttempts() {
        testAttempts = 0
    }

    func addLog(_ entry: LogEntry) {
        logs.append(entry)
        if logs.count > Self.maxLogEntries {
            logs.removeFirst(logs.count - Self.maxLogEntries)
        }
    }

    func addLog(type: LogType, message: String) {
        let entry = LogEntry(
            phase: phase,
            type: type,
            message: message
        )
        logs.append(entry)
        if logs.count > Self.maxLogEntries {
            logs.removeFirst(logs.count - Self.maxLogEntries)
        }
    }

    func addError(_ error: ExecutionError) {
        errors.append(error)
        if errors.count > Self.maxErrorEntries {
            errors.removeFirst(errors.count - Self.maxErrorEntries)
        }
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
        if errors.count > Self.maxErrorEntries {
            errors.removeFirst(errors.count - Self.maxErrorEntries)
        }
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

    // MARK: - Image Management

    func addImage(_ image: AttachedImage) {
        attachedImages.append(image)
    }

    func removeImage(id: UUID) {
        attachedImages.removeAll { $0.id == id }
    }

    func removeAllImages() {
        attachedImages.removeAll()
    }

    // MARK: - Fallback Management

    func triggerFallback(reason: FallbackReason) {
        isInFallbackMode = true
        fallbackReason = reason
        addLog(type: .info, message: "Switching to manual mode: \(reason.displayMessage)")
    }

    func resetFallbackState() {
        isInFallbackMode = false
        consecutiveCommandFailures = 0
        fallbackReason = nil
        autonomousModeOverride = nil
    }

    func incrementCommandFailure() -> Bool {
        consecutiveCommandFailures += 1
        let threshold = autonomousConfig.consecutiveFailuresBeforeFallback
        if consecutiveCommandFailures >= threshold && autonomousConfig.fallbackOnCommandFailure {
            triggerFallback(reason: .consecutiveFailures(consecutiveCommandFailures))
            return true
        }
        return false
    }

    func resetCommandFailureCount() {
        consecutiveCommandFailures = 0
    }
}
