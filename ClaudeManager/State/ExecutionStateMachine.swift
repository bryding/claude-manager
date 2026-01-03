import Foundation

// MARK: - Execution State Machine Error

enum ExecutionStateMachineError: Error, LocalizedError {
    case noProjectPath
    case emptyFeatureDescription
    case notPaused
    case noSessionId
    case executionFailed(String)
    case noExistingPlan

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
        case .executionFailed(let phase):
            return "Execution failed during \(phase)"
        case .noExistingPlan:
            return "No existing plan loaded"
        }
    }
}

// MARK: - Execution State Machine

@MainActor
final class ExecutionStateMachine {
    // MARK: - Dependencies

    let context: ExecutionContext
    let claudeService: any ClaudeCLIServiceProtocol
    let planService: PlanService
    let gitService: any GitServiceProtocol
    let buildTestService: any BuildTestServiceProtocol
    let userPreferences: UserPreferences

    // MARK: - Private State

    private var isPaused = false
    private var shouldStop = false
    private var phaseBeforePause: ExecutionPhase?
    private var pendingAutoAnswerQuestion: PendingQuestion?
    private var questionAskedDuringPhase = false

    // MARK: - Initialization

    init(
        context: ExecutionContext,
        claudeService: any ClaudeCLIServiceProtocol,
        planService: PlanService,
        gitService: any GitServiceProtocol,
        buildTestService: any BuildTestServiceProtocol,
        userPreferences: UserPreferences
    ) {
        self.context = context
        self.claudeService = claudeService
        self.planService = planService
        self.gitService = gitService
        self.buildTestService = buildTestService
        self.userPreferences = userPreferences
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
        context.interviewSession = InterviewSession(featureDescription: context.featureDescription)
        context.startTime = Date()
        context.phase = .conductingInterview
        context.addLog(type: .info, message: "Starting feature interview")

        await runLoop()
    }

    func startWithExistingPlan() async throws {
        guard context.projectPath != nil else {
            throw ExecutionStateMachineError.noProjectPath
        }

        guard let existingPlan = context.existingPlan else {
            throw ExecutionStateMachineError.noExistingPlan
        }

        resetState()
        context.plan = existingPlan
        context.startTime = Date()
        context.addLog(type: .info, message: "Starting execution from existing plan")

        if let firstPendingIndex = findFirstPendingTask(in: existingPlan) {
            context.currentTaskIndex = firstPendingIndex
            context.phase = .executingTask
            context.addLog(type: .info, message: "Resuming from task \(firstPendingIndex + 1): \(existingPlan.tasks[firstPendingIndex].title)")
        } else {
            context.phase = .completed
            context.addLog(type: .info, message: "All tasks already completed")
        }

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

        // Record interview answer if this was an interview question
        if let currentQuestion = context.currentInterviewQuestion,
           var session = context.interviewSession,
           !session.isComplete {
            session.addExchange(question: currentQuestion, answer: answer)
            context.interviewSession = session
            context.currentInterviewQuestion = nil
            context.phase = .conductingInterview
        }

        context.pendingQuestion = nil
        context.addLog(type: .info, message: "User answered: \(answer)")

        await runLoop()
    }

    func sendManualInput(_ input: String) async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        guard let sessionId = context.sessionId else {
            throw ExecutionStateMachineError.noSessionId
        }

        context.addLog(type: .info, message: "User input: \(input)")

        let isInterviewPhase = context.phase == .conductingInterview
        let permissionMode: PermissionMode = switch context.phase {
        case .conductingInterview, .generatingInitialPlan, .rewritingPlan:
            .plan
        default:
            .acceptEdits
        }

        let result = try await claudeService.execute(
            prompt: input,
            workingDirectory: projectPath,
            permissionMode: permissionMode,
            sessionId: sessionId,
            timeout: context.timeoutConfiguration.executionTimeout,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    if isInterviewPhase {
                        self.handleInterviewMessage(message)
                    } else {
                        self.handleStreamMessage(message)
                    }
                }
            }
        )

        if result.isError {
            context.addLog(type: .error, message: "Manual input execution failed")
            throw ExecutionStateMachineError.executionFailed("sendManualInput")
        }

        context.addLog(type: .info, message: "Manual input processed successfully")

        if context.phase != .waitingForUser && !context.phase.isTerminal {
            await runLoop()
        }
    }

    func handleTaskFailureResponse(_ response: TaskFailureResponse) async {
        guard context.pendingTaskFailure != nil else { return }

        context.pendingTaskFailure = nil
        context.addLog(type: .info, message: "User selected: \(response.rawValue)")

        switch response {
        case .retry:
            context.resetRetryAttempt()
            context.phase = .executingTask
            context.addLog(type: .info, message: "Retrying task")
            await runLoop()

        case .skip:
            context.updateTaskStatus(.skipped)
            context.addLog(type: .info, message: "Skipping task")
            context.phase = .clearingContext
            await runLoop()

        case .stop:
            markCurrentTaskFailed()
            context.phase = .failed
            context.addLog(type: .info, message: "Execution stopped by user after task failure")
        }
    }

    // MARK: - Private Methods

    private func resetState() {
        isPaused = false
        shouldStop = false
        phaseBeforePause = nil
        context.autonomousConfig = userPreferences.autonomousConfig
    }

    /// Handles phase errors with autonomous failure handling support.
    /// Returns true if the loop should continue (retry or skip), false if it should exit.
    private func handlePhaseError(_ error: Error) -> Bool {
        context.addError(
            message: "Execution failed during \(context.phase.rawValue)",
            underlyingError: error.localizedDescription,
            isRecoverable: true
        )
        context.addLog(type: .error, message: "Phase failed: \(error.localizedDescription)")

        if let task = context.currentTask, context.phase == .executingTask {
            let config = context.autonomousConfig

            // Check if autonomous failure handling is enabled
            if config.autoFailureHandling != .pauseForUser {
                context.taskFailureCount += 1
                context.addLog(type: .info, message: "Task failure \(context.taskFailureCount)/\(config.maxTaskRetries)")

                if context.taskFailureCount < config.maxTaskRetries {
                    // Retry the task
                    context.addLog(type: .info, message: "Auto-retrying task...")
                    context.resetRetryAttempt()
                    context.phase = .executingTask
                    return true
                }

                // Max retries exceeded - handle based on mode
                switch config.autoFailureHandling {
                case .retryThenSkip:
                    context.addLog(type: .info, message: "Max retries exceeded, skipping task")
                    context.updateTaskStatus(.skipped)
                    context.taskFailureCount = 0
                    context.phase = .clearingContext
                    return true
                case .retryThenStop:
                    context.addLog(type: .error, message: "Max retries exceeded, stopping execution")
                    markCurrentTaskFailed()
                    context.phase = .failed
                    return false
                case .pauseForUser:
                    break
                }
            }

            // Default behavior: pause for user input
            context.pendingTaskFailure = PendingTaskFailure(
                taskNumber: task.number,
                taskTitle: task.title,
                error: error.localizedDescription
            )
            context.phase = .waitingForUser
            context.addLog(type: .info, message: "Waiting for user input on task failure")
            return false
        } else {
            return handleBuildTestPhaseError()
        }
    }

    private func handleBuildTestPhaseError() -> Bool {
        switch context.phase {
        case .runningBuild:
            context.addLog(type: .info, message: "Build failed, attempting to fix errors")
            context.phase = .fixingBuildErrors
            return true

        case .runningTests:
            context.addLog(type: .info, message: "Tests failed, attempting to fix errors")
            context.phase = .fixingTestErrors
            return true

        case .fixingBuildErrors:
            if context.buildAttempts < ExecutionContext.maxBuildFixAttempts {
                context.addLog(type: .info, message: "Build fix failed, retrying build")
                context.phase = .runningBuild
                return true
            } else {
                context.addLog(type: .error, message: "Max build fix attempts reached")
                markCurrentTaskFailed()
                context.phase = .failed
                return false
            }

        case .fixingTestErrors:
            if context.testAttempts < ExecutionContext.maxTestFixAttempts {
                context.addLog(type: .info, message: "Test fix failed, retrying tests")
                context.phase = .runningTests
                return true
            } else {
                context.addLog(type: .error, message: "Max test fix attempts reached")
                markCurrentTaskFailed()
                context.phase = .failed
                return false
            }

        default:
            markCurrentTaskFailed()
            context.phase = .failed
            return false
        }
    }

    // MARK: - Main Loop

    private func runLoop() async {
        while !context.phase.isTerminal && !shouldStop && !isPaused {
            if context.phase == .waitingForUser {
                break
            }

            if context.isHandoffInProgress && context.phase != .handlingContextExhaustion {
                context.phase = .handlingContextExhaustion
            }

            do {
                try await executeCurrentPhase()
            } catch {
                if context.isHandoffInProgress {
                    context.phase = .handlingContextExhaustion
                    continue
                }
                let shouldContinue = handlePhaseError(error)
                if !shouldContinue {
                    return
                }
                continue
            }

            if questionAskedDuringPhase {
                questionAskedDuringPhase = false
                break
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

        case .conductingInterview:
            try await executeWithRetry(operationName: "Interview") {
                try await conductInterview()
            }

        case .generatingInitialPlan:
            try await executeWithRetry(operationName: "Generate plan") {
                try await generateInitialPlan()
            }

        case .rewritingPlan:
            try await executeWithRetry(operationName: "Rewrite plan") {
                try await rewritePlanToFormat()
            }

        case .executingTask:
            markCurrentTaskInProgress()
            try await executeWithRetry(operationName: "Execute task") {
                try await executeCurrentTask()
            }

        case .committingImplementation:
            try await commitChanges(message: commitMessageForImplementation())

        case .reviewingCode:
            try await executeWithRetry(operationName: "Code review") {
                try await runCodeReview()
            }

        case .committingReview:
            try await commitChanges(message: commitMessageForReview())

        case .writingTests:
            try await executeWithRetry(operationName: "Write tests") {
                try await writeTests()
            }

        case .committingTests:
            try await commitChanges(message: commitMessageForTests())

        case .clearingContext:
            try await clearContext()

        case .handlingContextExhaustion:
            try await handleContextExhaustion()

        case .runningBuild:
            try await executeWithRetry(operationName: "Build") {
                try await runBuild()
            }

        case .runningTests:
            try await executeWithRetry(operationName: "Tests") {
                try await runTests()
            }

        case .fixingBuildErrors:
            try await executeWithRetry(operationName: "Fix build errors") {
                try await fixBuildErrors()
            }

        case .fixingTestErrors:
            try await executeWithRetry(operationName: "Fix test errors") {
                try await fixTestErrors()
            }

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

        case .conductingInterview:
            if context.interviewSession?.isComplete == true {
                context.phase = .generatingInitialPlan
            }

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
            context.taskFailureCount = 0
            context.phase = .committingImplementation

        case .committingImplementation:
            if context.autonomousConfig.runBuildAfterCommit {
                context.resetBuildAttempts()
                context.phase = .runningBuild
            } else {
                context.phase = .reviewingCode
            }

        case .reviewingCode:
            context.phase = .committingReview

        case .committingReview:
            if shouldWriteTests() {
                context.phase = .writingTests
            } else {
                if let task = context.currentTask {
                    context.addLog(type: .info, message: "Skipping tests for UI-related task: \(task.title)")
                }
                context.phase = .clearingContext
            }

        case .writingTests:
            context.phase = .committingTests

        case .committingTests:
            if context.autonomousConfig.runTestsAfterCommit {
                context.resetTestAttempts()
                context.phase = .runningTests
            } else {
                context.phase = .clearingContext
            }

        case .clearingContext:
            advanceToNextTaskOrComplete()

        case .handlingContextExhaustion:
            context.phase = .executingTask

        case .runningBuild:
            context.phase = .reviewingCode

        case .fixingBuildErrors:
            context.phase = .runningBuild

        case .runningTests:
            context.phase = .clearingContext

        case .fixingTestErrors:
            context.phase = .runningTests

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

        return !isUIRelatedTask(task)
    }

    private func isUIRelatedTask(_ task: PlanTask) -> Bool {
        let uiKeywords = [
            "view", "ui", "layout", "animation", "style", "color", "font",
            "icon", "image", "button", "label", "text", "visual", "display",
            "indicator", "sheet", "modal", "navigation", "sidebar"
        ]

        let titleLower = task.title.lowercased()
        let descriptionLower = task.description.lowercased()

        return uiKeywords.contains { keyword in
            titleLower.contains(keyword) || descriptionLower.contains(keyword)
        }
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

    private func findFirstPendingTask(in plan: Plan) -> Int? {
        return plan.tasks.firstIndex { $0.status == .pending }
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

    // MARK: - Prompt Helpers

    private func buildProjectContextSection() -> String {
        guard !context.autonomousConfig.projectContext.isEmpty else { return "" }
        return """
            ## Project Context
            \(context.autonomousConfig.projectContext)

            """
    }

    // MARK: - Context Handoff Helpers

    private var canTriggerContextHandoff: Bool {
        switch context.phase {
        case .executingTask, .reviewingCode, .writingTests:
            return true
        default:
            return false
        }
    }

    // MARK: - Message Handling

    private enum MessageHandlerMode {
        case standard
        case interview
    }

    private func handleStreamMessage(_ message: ClaudeStreamMessage) {
        handleMessage(message, mode: .standard)
    }

    private func handleInterviewMessage(_ message: ClaudeStreamMessage) {
        handleMessage(message, mode: .interview)
    }

    private func handleMessage(_ message: ClaudeStreamMessage, mode: MessageHandlerMode) {
        switch message {
        case .system(let systemMsg):
            context.sessionId = systemMsg.sessionId

        case .assistant(let assistantMsg):
            context.sessionId = assistantMsg.sessionId

            for block in assistantMsg.message.content {
                switch block {
                case .text(let textContent):
                    context.addLog(type: .output, message: textContent.text)

                    if mode == .interview && textContent.text.contains("INTERVIEW_COMPLETE") {
                        context.interviewSession?.markComplete()
                    }

                case .toolUse(let toolUse):
                    if toolUse.isAskUserQuestion {
                        handleAskUserQuestion(toolUse, mode: mode)
                    } else {
                        context.addLog(type: .toolUse, message: "Tool: \(toolUse.name)")
                    }
                }
            }

            if let usage = assistantMsg.message.usage {
                context.accumulateUsage(
                    inputTokens: usage.inputTokens,
                    outputTokens: usage.outputTokens
                )
                if mode == .standard {
                    checkForContextExhaustion()
                }
            }

        case .result(let resultMsg):
            context.sessionId = resultMsg.sessionId
            context.totalCost += resultMsg.totalCostUsd
            context.accumulateUsage(
                inputTokens: resultMsg.usage.inputTokens,
                outputTokens: resultMsg.usage.outputTokens
            )
            if mode == .standard {
                checkForContextExhaustion()
            }

        case .user:
            break
        }
    }

    private func handleAskUserQuestion(_ toolUse: ToolUseContent, mode: MessageHandlerMode) {
        guard let input = toolUse.askUserQuestionInput,
              let firstQuestion = input.questions.first else {
            return
        }

        let pendingQuestion = PendingQuestion(
            toolUseId: toolUse.id,
            question: firstQuestion
        )

        switch mode {
        case .interview:
            context.currentInterviewQuestion = firstQuestion.question
            context.pendingQuestion = pendingQuestion
            context.phase = .waitingForUser
            questionAskedDuringPhase = true

        case .standard:
            if context.autonomousConfig.autoAnswerEnabled {
                pendingAutoAnswerQuestion = pendingQuestion
            } else {
                context.pendingQuestion = pendingQuestion
                context.phase = .waitingForUser
            }
        }
    }

    // MARK: - Phase Handlers

    private static let maxInterviewQuestions = 5

    private func conductInterview() async throws {
        questionAskedDuringPhase = false

        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        guard let interviewSession = context.interviewSession else {
            context.addLog(type: .error, message: "No interview session found")
            return
        }

        let questionCount = interviewSession.exchanges.count

        if questionCount >= Self.maxInterviewQuestions {
            context.addLog(type: .info, message: "Maximum interview questions reached, proceeding to plan generation")
            context.interviewSession?.markComplete()
            return
        }

        let previousExchanges: String
        if interviewSession.exchanges.isEmpty {
            previousExchanges = ""
        } else {
            previousExchanges = """

                ## Previous Clarifications
                \(interviewSession.promptContext)

                """
        }

        let prompt = """
            You are gathering requirements for a software feature. Analyze the following feature request and ask ONE clarifying question that would help create a better implementation plan.

            ## Feature Request
            \(interviewSession.featureDescription)
            \(previousExchanges)
            ## Instructions
            1. If the feature request is clear enough to proceed with planning, respond with exactly: INTERVIEW_COMPLETE
            2. Otherwise, use the AskUserQuestion tool to ask ONE important clarifying question
            3. Focus on: ambiguous requirements, technical decisions, scope boundaries
            4. Do NOT ask about implementation details you can decide yourself
            5. Maximum \(Self.maxInterviewQuestions) questions total. You have asked \(questionCount) so far.
            """

        context.addLog(type: .info, message: "Conducting interview (question \(questionCount + 1)/\(Self.maxInterviewQuestions) max)")

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .plan,
            sessionId: context.sessionId,
            timeout: context.timeoutConfiguration.planModeTimeout,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleInterviewMessage(message)
                }
            }
        )

        if result.isError {
            context.addLog(type: .error, message: "Interview phase failed")
            throw ExecutionStateMachineError.executionFailed("conductInterview")
        }

        // Auto-complete fallback: if Claude responded without asking a question and
        // the interview isn't already complete, mark it complete
        if context.interviewSession?.isComplete != true
            && context.pendingQuestion == nil
            && !questionAskedDuringPhase {
            context.addLog(type: .info, message: "Claude responded without asking more questions, completing interview")
            context.interviewSession?.markComplete()
        }

        if context.interviewSession?.isComplete == true {
            context.addLog(type: .info, message: "Interview completed, proceeding to plan generation")
        }
    }

    private func generateInitialPlan() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        let interviewContext = context.interviewSession?.promptContext ?? ""
        let clarificationsSection: String
        if interviewContext.isEmpty {
            clarificationsSection = ""
        } else {
            clarificationsSection = """


                ## Clarifications from User
                \(interviewContext)

                """
        }

        let prompt = """
            Analyze the following feature request and create a high-level implementation plan:

            \(context.featureDescription)\(clarificationsSection)
            Create a structured plan with discrete, implementable tasks. Use this format:

            ## Task 1: Task Title
            **Description:** Brief description of what this task accomplishes
            - [ ] Subtask or acceptance criteria
            - [ ] Another subtask

            ## Task 2: Next Task Title
            ...and so on.

            Focus on breaking down the work into small, focused tasks that can be completed independently.
            """

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .plan,
            sessionId: nil,
            timeout: context.timeoutConfiguration.planModeTimeout,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleStreamMessage(message)
                }
            }
        )

        if result.isError {
            throw ExecutionStateMachineError.executionFailed("generateInitialPlan")
        }

        let plan = planService.parsePlanFromText(result.result)
        context.plan = plan
        context.addLog(type: .info, message: "Initial plan generated with \(plan.tasks.count) tasks")
    }

    private func rewritePlanToFormat() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        let prompt = """
            Review the plan and ensure it follows this exact format for each task:

            ## Task N: Task Title
            **Description:** Brief description of what this task accomplishes
            - [ ] Subtask or acceptance criteria
            - [ ] Another subtask

            Make sure:
            1. Tasks are numbered sequentially starting from 1
            2. Each task has a clear, actionable title
            3. Each task has a description
            4. Subtasks are concrete acceptance criteria

            Output only the reformatted plan, nothing else.
            """

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .plan,
            sessionId: context.sessionId,
            timeout: context.timeoutConfiguration.planModeTimeout,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleStreamMessage(message)
                }
            }
        )

        if result.isError {
            context.addLog(type: .error, message: "Failed to rewrite plan")
            return
        }

        let plan = planService.parsePlanFromText(result.result)
        context.plan = plan
        context.addLog(type: .info, message: "Plan reformatted with \(plan.tasks.count) tasks")
    }

    private func executeCurrentTask() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        guard let task = context.currentTask else {
            context.addLog(type: .error, message: "No current task to execute")
            return
        }

        let subtasksText = task.subtasks.isEmpty
            ? "No specific subtasks defined."
            : task.subtasks.enumerated().map { "- \($0.element)" }.joined(separator: "\n")

        var continuationContext = ""
        if let summary = context.continuationSummary {
            continuationContext = summary.promptContext
            context.addLog(type: .info, message: "Resuming task with continuation context")
            context.continuationSummary = nil
        }

        let projectContextSection = buildProjectContextSection()

        let completedTasksSection: String = {
            let completed = context.plan?.tasks.filter { $0.status == .completed } ?? []
            guard !completed.isEmpty else { return "" }
            let completedList = completed.map { "- Task \($0.number): \($0.title)" }.joined(separator: "\n")
            return """
                ## Previously Completed Tasks
                \(completedList)

                """
        }()

        let prompt = """
            \(continuationContext)\(projectContextSection)\(completedTasksSection)Execute the following task:

            ## Task \(task.number): \(task.title)
            \(task.description)

            ## Acceptance Criteria
            \(subtasksText)

            ## Instructions
            - Implement this task completely, creating or modifying files as needed
            - Follow existing code patterns and conventions in the project
            - Reference plan.md in the project root to understand the overall implementation plan
            - Build on work from previously completed tasks where relevant
            """

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .acceptEdits,
            sessionId: context.sessionId,
            timeout: context.timeoutConfiguration.executionTimeout,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleStreamMessage(message)
                }
            }
        )

        if try await processAutoAnswerIfNeeded() {
            return
        }

        if context.isHandoffInProgress {
            context.phase = .handlingContextExhaustion
            return
        }

        if result.isError {
            context.addLog(type: .error, message: "Task execution failed")
            throw ExecutionStateMachineError.executionFailed("executeCurrentTask")
        }

        context.addLog(type: .info, message: "Task \(task.number) execution completed")
    }

    private func runCodeReview() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        guard let task = context.currentTask else {
            context.addLog(type: .info, message: "Skipping code review: no current task")
            return
        }

        let projectContextSection = buildProjectContextSection()

        let taskSection = """
            ## Task Being Reviewed
            **Task \(task.number): \(task.title)**
            \(task.description)

            """

        let prompt = """
            \(projectContextSection)\(taskSection)Review the code changes just made for this task.

            Run /codereview and evaluate against these criteria:

            ## Code Quality
            - DRY: Is there duplicated code that should be extracted?
            - Naming: Are variables, functions, and types clearly named?
            - Readability: Is the code easy to understand?

            ## Correctness
            - Edge cases: Are boundary conditions handled?
            - Error handling: Are errors properly caught and handled?
            - Null safety: Are optionals properly unwrapped?

            ## Best Practices
            - Swift conventions: Does it follow Swift idioms?
            - Project patterns: Does it match existing codebase patterns?
            - Performance: Any obvious inefficiencies?

            If you find issues, fix them. If the code looks good, confirm it meets quality standards.
            """

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .acceptEdits,
            sessionId: context.sessionId,
            timeout: context.timeoutConfiguration.executionTimeout,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleStreamMessage(message)
                }
            }
        )

        if try await processAutoAnswerIfNeeded() {
            return
        }

        if result.isError {
            context.addLog(type: .error, message: "Code review encountered an error")
        } else {
            context.addLog(type: .info, message: "Code review completed")
        }
    }

    private func writeTests() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        guard let task = context.currentTask else {
            context.addLog(type: .info, message: "Skipping tests: no current task")
            return
        }

        context.addLog(type: .info, message: "Writing tests for \(task.title)")

        let projectContextSection = buildProjectContextSection()

        let taskSection = """
            ## Task Being Tested
            **Task \(task.number): \(task.title)**
            \(task.description)

            """

        let prompt = """
            \(projectContextSection)\(taskSection)Write unit tests for the code implemented in this task.

            Run /writetests to create tests covering:

            ## Core Functionality
            - Happy path: Test the main expected behavior works correctly
            - Input variations: Test with different valid inputs
            - Return values: Verify correct outputs and state changes

            ## Edge Cases
            - Boundary conditions: Min/max values, empty collections, single elements
            - Nil/optional handling: Test nil inputs where applicable
            - State transitions: Verify before/after state is correct

            ## Error Handling
            - Invalid inputs: Test rejection of bad data
            - Failure scenarios: Test error paths are handled gracefully
            - Error messages: Verify meaningful error information

            ## Guidelines
            - Follow Arrange-Act-Assert pattern for test structure
            - Match existing test patterns in the project
            - Use XCTest framework
            - Focus on core logic, skip UI components and trivial getters/setters
            - Write tests that catch regressions, not just for coverage
            """

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .acceptEdits,
            sessionId: context.sessionId,
            timeout: context.timeoutConfiguration.executionTimeout,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleStreamMessage(message)
                }
            }
        )

        if try await processAutoAnswerIfNeeded() {
            return
        }

        if result.isError {
            context.addLog(type: .error, message: "Test writing encountered an error")
        } else {
            context.addLog(type: .info, message: "Tests written successfully")
        }
    }

    private func commitChanges(message: String) async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        context.addLog(type: .info, message: "Committing: \(message)")

        let result = try await gitService.commitAll(message: message, in: projectPath)

        switch result {
        case .committed(let output):
            if let output = output {
                context.addLog(type: .info, message: "Commit successful: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            } else {
                context.addLog(type: .info, message: "Commit successful")
            }
        case .noChanges:
            context.addLog(type: .info, message: "No changes to commit")
        }
    }

    // MARK: - Build/Test Phase Handlers

    private func runBuild() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        context.addLog(type: .info, message: "Running build...")
        context.buildAttempts += 1

        let result = try await buildTestService.runBuild(
            in: projectPath,
            config: context.projectConfiguration
        )

        context.lastBuildResult = result

        if result.success {
            context.addLog(type: .info, message: "Build succeeded")
        } else {
            let errorMsg = result.errorOutput ?? result.output
            context.addLog(type: .error, message: "Build failed:\n\(errorMsg)")
            throw ExecutionStateMachineError.executionFailed("runBuild")
        }
    }

    private func runTests() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        context.addLog(type: .info, message: "Running tests...")
        context.testAttempts += 1

        let result = try await buildTestService.runTests(
            in: projectPath,
            config: context.projectConfiguration
        )

        context.lastTestResult = result

        if result.success {
            context.addLog(type: .info, message: "Tests passed")
        } else {
            let errorMsg = result.errorOutput ?? result.output
            context.addLog(type: .error, message: "Tests failed:\n\(errorMsg)")
            throw ExecutionStateMachineError.executionFailed("runTests")
        }
    }

    private func fixBuildErrors() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        guard let buildResult = context.lastBuildResult else {
            throw ExecutionStateMachineError.executionFailed("fixBuildErrors: no build result")
        }

        let errorOutput = buildResult.errorOutput ?? buildResult.output

        let prompt = """
            The build failed with the following errors:

            ```
            \(errorOutput)
            ```

            Please fix these build errors. Make the minimal changes necessary to resolve them.
            After fixing, run /commit to commit your changes.
            """

        context.addLog(type: .info, message: "Asking Claude to fix build errors (attempt \(context.buildAttempts))")

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .acceptEdits,
            sessionId: context.sessionId,
            timeout: context.timeoutConfiguration.executionTimeout,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleStreamMessage(message)
                }
            }
        )

        if try await processAutoAnswerIfNeeded() {
            return
        }

        if context.isHandoffInProgress {
            context.phase = .handlingContextExhaustion
            return
        }

        if result.isError {
            context.addLog(type: .error, message: "Fix build errors encountered an error")
            throw ExecutionStateMachineError.executionFailed("fixBuildErrors")
        }

        context.addLog(type: .info, message: "Build error fix attempt completed")
    }

    private func fixTestErrors() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        guard let testResult = context.lastTestResult else {
            throw ExecutionStateMachineError.executionFailed("fixTestErrors: no test result")
        }

        let errorOutput = testResult.errorOutput ?? testResult.output

        let prompt = """
            The tests failed with the following output:

            ```
            \(errorOutput)
            ```

            Please fix these test failures. Either fix the code if there's a bug,
            or fix the test if it's incorrect.
            After fixing, run /commit to commit your changes.
            """

        context.addLog(type: .info, message: "Asking Claude to fix test failures (attempt \(context.testAttempts))")

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .acceptEdits,
            sessionId: context.sessionId,
            timeout: context.timeoutConfiguration.executionTimeout,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleStreamMessage(message)
                }
            }
        )

        if try await processAutoAnswerIfNeeded() {
            return
        }

        if context.isHandoffInProgress {
            context.phase = .handlingContextExhaustion
            return
        }

        if result.isError {
            context.addLog(type: .error, message: "Fix test errors encountered an error")
            throw ExecutionStateMachineError.executionFailed("fixTestErrors")
        }

        context.addLog(type: .info, message: "Test error fix attempt completed")
    }

    private func clearContext() async throws {
        context.sessionId = nil
        context.resetRetryAttempt()
        context.addLog(type: .info, message: "Context cleared for next task")
    }

    // MARK: - Retry Logic

    private func executeWithRetry<T>(
        operationName: String,
        operation: () async throws -> T
    ) async throws -> T {
        let config = context.retryConfiguration
        context.currentRetryAttempt = 0

        while true {
            context.currentRetryAttempt += 1

            do {
                let result = try await operation()
                if context.currentRetryAttempt > 1 {
                    context.addLog(type: .info, message: "\(operationName) succeeded on attempt \(context.currentRetryAttempt)")
                }
                return result
            } catch {
                let isRetryable = (error as? ClaudeProcessError)?.isRetryable
                    ?? (error as? ClaudeCLIServiceError)?.isRetryable
                    ?? false

                if !isRetryable || context.currentRetryAttempt >= config.maxAttempts {
                    context.addLog(
                        type: .error,
                        message: "\(operationName) failed after \(context.currentRetryAttempt) attempt(s): \(error.localizedDescription)"
                    )
                    throw error
                }

                let delay = config.delay(for: context.currentRetryAttempt)
                context.addLog(
                    type: .info,
                    message: "\(operationName) failed (attempt \(context.currentRetryAttempt)/\(config.maxAttempts)), retrying in \(Int(delay))s..."
                )

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    // MARK: - Context Exhaustion Handling

    private func checkForContextExhaustion() {
        guard context.isContextLow,
              !context.isHandoffInProgress,
              canTriggerContextHandoff else {
            return
        }

        context.isHandoffInProgress = true
        let usagePercent = Int(context.contextPercentUsed * 100)
        context.addLog(
            type: .info,
            message: "Context usage high (\(usagePercent)%), initiating handoff"
        )
        claudeService.interrupt()
    }

    private func handleContextExhaustion() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        guard let task = context.currentTask else {
            context.addLog(type: .error, message: "No current task during context exhaustion")
            context.isHandoffInProgress = false
            return
        }

        context.addLog(type: .info, message: "Creating WIP commit before context clear")

        // Step 1: Create WIP commit
        try await createWIPCommit(for: task, in: projectPath)

        // Step 2: Generate continuation summary
        try await generateContinuationSummary(for: task, in: projectPath)

        // Step 3: Clear context
        context.sessionId = nil
        context.lastInputTokenCount = 0
        context.isHandoffInProgress = false

        context.addLog(type: .info, message: "Context cleared, resuming with continuation summary")
    }

    private func createWIPCommit(for task: PlanTask, in projectPath: URL) async throws {
        let message = "WIP: Task \(task.number) - \(task.title) (context handoff)"

        let result = try await gitService.commitAll(message: message, in: projectPath)

        switch result {
        case .committed(let output):
            let outputText = output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            context.addLog(type: .info, message: "WIP commit created: \(outputText)")
        case .noChanges:
            context.addLog(type: .info, message: "No changes to commit during handoff")
        }
    }

    private func generateContinuationSummary(for task: PlanTask, in projectPath: URL) async throws {
        let prompt = """
            Generate a concise continuation summary for the current task progress.

            Task: \(task.number) - \(task.title)
            Description: \(task.description)

            Analyze the current state and provide:
            1. A brief description of what has been accomplished (2-3 sentences max)
            2. List of files that were modified (file paths only)
            3. What remains to be done to complete this task (2-3 sentences max)

            Output ONLY in this exact JSON format, nothing else:
            {
                "progressDescription": "...",
                "filesModified": ["path1", "path2"],
                "pendingWork": "..."
            }
            """

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .plan,
            sessionId: nil,
            timeout: context.timeoutConfiguration.planModeTimeout,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    if case .assistant(let assistantMsg) = message {
                        for block in assistantMsg.message.content {
                            if case .text(let textContent) = block {
                                self.context.addLog(type: .output, message: "[Summary] \(textContent.text)")
                            }
                        }
                    }
                }
            }
        )

        if result.isError {
            context.addLog(type: .error, message: "Failed to generate continuation summary")
            context.continuationSummary = createFallbackSummary(for: task)
            return
        }

        if let summary = parseContinuationSummary(from: result.result, task: task) {
            context.continuationSummary = summary
            context.addLog(type: .info, message: "Continuation summary generated successfully")
        } else {
            context.continuationSummary = createFallbackSummary(for: task, with: result.result)
        }
    }

    private func createFallbackSummary(for task: PlanTask, with rawText: String? = nil) -> ContinuationSummary {
        let progressDescription = rawText.map { String($0.prefix(500)) }
            ?? "Previous session was interrupted due to context limits."

        return ContinuationSummary(
            taskNumber: task.number,
            taskTitle: task.title,
            progressDescription: progressDescription,
            filesModified: [],
            pendingWork: "Continue implementing \(task.title) as described in the task requirements."
        )
    }

    private func parseContinuationSummary(from jsonString: String, task: PlanTask) -> ContinuationSummary? {
        var cleanedJSON = jsonString

        if let startRange = jsonString.range(of: "{"),
           let endRange = jsonString.range(of: "}", options: .backwards) {
            cleanedJSON = String(jsonString[startRange.lowerBound...endRange.upperBound])
        }

        guard let data = cleanedJSON.data(using: .utf8) else { return nil }

        struct SummaryResponse: Decodable {
            let progressDescription: String
            let filesModified: [String]
            let pendingWork: String
        }

        guard let response = try? JSONDecoder().decode(SummaryResponse.self, from: data) else {
            return nil
        }

        return ContinuationSummary(
            taskNumber: task.number,
            taskTitle: task.title,
            progressDescription: response.progressDescription,
            filesModified: response.filesModified,
            pendingWork: response.pendingWork
        )
    }

    // MARK: - Smart Auto-Answer

    private func generateSmartAnswer(for pendingQuestion: PendingQuestion) async throws -> String {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        let question = pendingQuestion.question
        let config = context.autonomousConfig

        let optionsList = question.options.enumerated().map { index, opt in
            "\(index + 1). \(opt.label) - \(opt.description)"
        }.joined(separator: "\n")

        let taskContext = context.currentTask.map { task in
            "Current Task: \(task.number) - \(task.title)\nDescription: \(task.description)"
        } ?? "No current task"

        let planOverview = context.plan.map { plan in
            let taskList = plan.tasks.prefix(10).map { "\($0.number). \($0.title) [\($0.status.rawValue)]" }
            return "Plan Tasks:\n" + taskList.joined(separator: "\n")
        } ?? "No plan available"

        let prompt = """
            You are helping to automate a development workflow. Claude has asked a question during task execution and you need to choose the best answer.

            ## Project Context
            \(config.projectContext.isEmpty ? "No specific context provided" : config.projectContext)

            ## Current State
            \(taskContext)

            \(planOverview)

            ## Question from Claude
            **\(question.header)**: \(question.question)

            Options:
            \(optionsList)

            ## Instructions
            Choose the option that best aligns with:
            1. The project context and goals
            2. Standard development best practices
            3. The current task being executed

            Respond with ONLY a JSON object in this format:
            {"choice": "exact option label here", "reasoning": "brief explanation"}
            """

        context.addLog(type: .info, message: "Generating smart answer for: \(question.header)")

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .plan,
            sessionId: nil,
            timeout: context.timeoutConfiguration.planModeTimeout,
            onMessage: { _ in }
        )

        if result.isError {
            context.addLog(type: .error, message: "Smart answer generation failed, using first option")
            return question.options.first?.label ?? "Continue"
        }

        if let choice = parseSmartAnswerResponse(result.result, options: question.options) {
            context.addLog(type: .info, message: "Smart answer selected: \(choice)")
            return choice
        }

        let fallback = question.options.first?.label ?? "Continue"
        context.addLog(type: .info, message: "Could not parse response, using fallback: \(fallback)")
        return fallback
    }

    private func parseSmartAnswerResponse(_ response: String, options: [AskUserQuestionInput.Option]) -> String? {
        var cleanedJSON = response

        if let startRange = response.range(of: "{"),
           let endRange = response.range(of: "}", options: .backwards) {
            cleanedJSON = String(response[startRange.lowerBound...endRange.upperBound])
        }

        guard let data = cleanedJSON.data(using: .utf8) else { return nil }

        struct SmartAnswerResponse: Decodable {
            let choice: String
            let reasoning: String?
        }

        guard let parsed = try? JSONDecoder().decode(SmartAnswerResponse.self, from: data) else {
            return nil
        }

        let validLabels = options.map { $0.label }
        if validLabels.contains(parsed.choice) {
            return parsed.choice
        }

        if let match = validLabels.first(where: { $0.lowercased() == parsed.choice.lowercased() }) {
            return match
        }

        return nil
    }

    private func processAutoAnswerIfNeeded() async throws -> Bool {
        guard let pendingQuestion = pendingAutoAnswerQuestion else {
            return false
        }

        guard let projectPath = context.projectPath,
              let sessionId = context.sessionId else {
            context.pendingQuestion = pendingQuestion
            context.phase = .waitingForUser
            pendingAutoAnswerQuestion = nil
            return true
        }

        pendingAutoAnswerQuestion = nil

        do {
            let answer = try await generateSmartAnswer(for: pendingQuestion)
            context.addLog(type: .info, message: "Auto-answered '\(pendingQuestion.question.header)': \(answer)")

            let result = try await claudeService.execute(
                prompt: answer,
                workingDirectory: projectPath,
                permissionMode: .acceptEdits,
                sessionId: sessionId,
                timeout: context.timeoutConfiguration.executionTimeout,
                onMessage: { [weak self] message in
                    guard let self = self else { return }
                    await MainActor.run {
                        self.handleStreamMessage(message)
                    }
                }
            )

            if pendingAutoAnswerQuestion != nil {
                return try await processAutoAnswerIfNeeded()
            }

            if result.isError {
                throw ExecutionStateMachineError.executionFailed("auto-answer resume")
            }

            return false

        } catch {
            context.addLog(type: .error, message: "Auto-answer failed: \(error.localizedDescription)")
            context.pendingQuestion = pendingQuestion
            context.phase = .waitingForUser
            return true
        }
    }
}
