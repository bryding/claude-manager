import Foundation

// MARK: - Execution State Machine Error

enum ExecutionStateMachineError: Error, LocalizedError {
    case noProjectPath
    case emptyFeatureDescription
    case notPaused
    case noSessionId
    case executionFailed(String)

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

    // MARK: - Private State

    private var isPaused = false
    private var shouldStop = false
    private var phaseBeforePause: ExecutionPhase?

    // MARK: - Initialization

    init(
        context: ExecutionContext,
        claudeService: any ClaudeCLIServiceProtocol,
        planService: PlanService,
        gitService: any GitServiceProtocol
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
                if let task = context.currentTask {
                    context.addLog(type: .info, message: "Skipping tests for UI-related task: \(task.title)")
                }
                context.phase = .clearingContext
            }

        case .writingTests:
            context.phase = .committingTests

        case .committingTests:
            context.phase = .clearingContext

        case .clearingContext:
            advanceToNextTaskOrComplete()

        case .handlingContextExhaustion:
            context.phase = .executingTask

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

    private func handleStreamMessage(_ message: ClaudeStreamMessage) {
        switch message {
        case .system(let systemMsg):
            context.sessionId = systemMsg.sessionId

        case .assistant(let assistantMsg):
            context.sessionId = assistantMsg.sessionId

            for block in assistantMsg.message.content {
                switch block {
                case .text(let textContent):
                    context.addLog(type: .output, message: textContent.text)

                case .toolUse(let toolUse):
                    if toolUse.isAskUserQuestion {
                        if let input = toolUse.askUserQuestionInput,
                           let firstQuestion = input.questions.first {
                            context.pendingQuestion = PendingQuestion(
                                toolUseId: toolUse.id,
                                question: firstQuestion
                            )
                            context.phase = .waitingForUser
                        }
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
                checkForContextExhaustion()
            }

        case .result(let resultMsg):
            context.sessionId = resultMsg.sessionId
            context.totalCost += resultMsg.totalCostUsd
            context.accumulateUsage(
                inputTokens: resultMsg.usage.inputTokens,
                outputTokens: resultMsg.usage.outputTokens
            )
            checkForContextExhaustion()

        case .user:
            break
        }
    }

    // MARK: - Phase Handlers

    private func generateInitialPlan() async throws {
        guard let projectPath = context.projectPath else {
            throw ExecutionStateMachineError.noProjectPath
        }

        let prompt = """
            Analyze the following feature request and create a high-level implementation plan:

            \(context.featureDescription)

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

        let prompt = """
            \(continuationContext)Execute the following task:

            ## Task \(task.number): \(task.title)
            \(task.description)

            Acceptance Criteria:
            \(subtasksText)

            Implement this task completely. Write the necessary code, create or modify files as needed.
            Make sure to follow existing code patterns and conventions in the project.
            """

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .acceptEdits,
            sessionId: context.sessionId,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleStreamMessage(message)
                }
            }
        )

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

        let prompt = """
            Review the code changes just made for task "\(task.title)".

            Run /codereview to check for:
            - Code quality and maintainability
            - Potential bugs or edge cases
            - Adherence to Swift best practices
            - DRY principles and code duplication
            - Proper error handling

            If you find issues, fix them. If the code looks good, confirm it meets quality standards.
            """

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .acceptEdits,
            sessionId: context.sessionId,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleStreamMessage(message)
                }
            }
        )

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

        let prompt = """
            Write unit tests for the code implemented in task "\(task.title)".

            Run /writetests to:
            - Test the main functionality
            - Cover edge cases and error conditions
            - Follow existing test patterns in the project
            - Use XCTest framework

            Focus on testing the core logic, not UI components or simple getters/setters.
            """

        let result = try await claudeService.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            permissionMode: .acceptEdits,
            sessionId: context.sessionId,
            onMessage: { [weak self] message in
                guard let self = self else { return }
                await MainActor.run {
                    self.handleStreamMessage(message)
                }
            }
        )

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
}
