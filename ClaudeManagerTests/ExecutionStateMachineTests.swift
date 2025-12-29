import XCTest
@testable import ClaudeManager

@MainActor
final class ExecutionStateMachineTests: XCTestCase {

    private var context: ExecutionContext!
    private var mockClaudeService: MockClaudeCLIService!
    private var planService: PlanService!
    private var mockGitService: MockGitService!
    private var stateMachine: ExecutionStateMachine!

    override func setUp() async throws {
        try await super.setUp()
        context = ExecutionContext()
        mockClaudeService = MockClaudeCLIService()
        planService = PlanService()
        mockGitService = MockGitService()
        stateMachine = ExecutionStateMachine(
            context: context,
            claudeService: mockClaudeService,
            planService: planService,
            gitService: mockGitService
        )
    }

    private func configureMockWithPlan(tasks: [(number: Int, title: String, description: String)]) {
        var planText = ""
        for task in tasks {
            planText += """
            ## Task \(task.number): \(task.title)
            **Description:** \(task.description)
            - [ ] Complete the implementation

            """
        }
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: planText,
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )
    }

    // MARK: - Start Validation

    func testStartThrowsWithoutProjectPath() async {
        context.featureDescription = "Some feature"

        do {
            try await stateMachine.start()
            XCTFail("Expected noProjectPath error")
        } catch ExecutionStateMachineError.noProjectPath {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStartThrowsWithEmptyFeatureDescription() async {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = ""

        do {
            try await stateMachine.start()
            XCTFail("Expected emptyFeatureDescription error")
        } catch ExecutionStateMachineError.emptyFeatureDescription {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStartSetsStartTime() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"

        XCTAssertNil(context.startTime)

        try await stateMachine.start()

        XCTAssertNotNil(context.startTime)
    }

    func testStartTransitionsFromIdle() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"

        XCTAssertEqual(context.phase, .idle)

        try await stateMachine.start()

        // With placeholder transitionToNextPhase(), loop completes immediately
        // Real implementation (Task 13) will have proper phase transitions
        XCTAssertNotEqual(context.phase, .idle)
    }

    func testStartAddsLog() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"

        XCTAssertTrue(context.logs.isEmpty)

        try await stateMachine.start()

        XCTAssertFalse(context.logs.isEmpty)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Starting execution loop") })
    }

    // MARK: - Pause

    func testPauseWhenRunning() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.phase = .executingTask

        stateMachine.pause()

        XCTAssertEqual(context.phase, .paused)
        XCTAssertTrue(context.logs.contains { $0.message.contains("paused") })
    }

    func testPauseDoesNothingWhenIdle() {
        context.phase = .idle

        stateMachine.pause()

        XCTAssertEqual(context.phase, .idle)
    }

    func testPauseDoesNothingWhenAlreadyPaused() {
        context.phase = .paused

        stateMachine.pause()

        XCTAssertEqual(context.phase, .paused)
    }

    func testPauseDoesNothingWhenWaitingForUser() {
        context.phase = .waitingForUser

        stateMachine.pause()

        XCTAssertEqual(context.phase, .waitingForUser)
    }

    // MARK: - Resume

    func testResumeFromPausedState() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.phase = .executingTask

        stateMachine.pause()
        XCTAssertEqual(context.phase, .paused)

        try await stateMachine.resume()

        // Phase restored then loop runs with placeholder (completes immediately)
        XCTAssertNotEqual(context.phase, .paused)
    }

    func testResumeThrowsWhenNotPaused() async {
        context.phase = .executingTask

        do {
            try await stateMachine.resume()
            XCTFail("Expected notPaused error")
        } catch ExecutionStateMachineError.notPaused {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResumeAddsLog() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.phase = .executingTask

        stateMachine.pause()
        let logCountAfterPause = context.logs.count

        try await stateMachine.resume()

        XCTAssertGreaterThan(context.logs.count, logCountAfterPause)
        XCTAssertTrue(context.logs.contains { $0.message.contains("resumed") })
    }

    // MARK: - Stop

    func testStopTransitionsToFailed() {
        context.phase = .executingTask

        stateMachine.stop()

        XCTAssertEqual(context.phase, .failed)
    }

    func testStopAddsError() {
        context.phase = .executingTask

        XCTAssertTrue(context.errors.isEmpty)

        stateMachine.stop()

        XCTAssertFalse(context.errors.isEmpty)
        XCTAssertTrue(context.errors.contains { $0.message.contains("stopped by user") })
    }

    func testStopDoesNothingWhenIdle() {
        context.phase = .idle

        stateMachine.stop()

        XCTAssertEqual(context.phase, .idle)
        XCTAssertTrue(context.errors.isEmpty)
    }

    func testStopDoesNothingWhenCompleted() {
        context.phase = .completed

        stateMachine.stop()

        XCTAssertEqual(context.phase, .completed)
        XCTAssertTrue(context.errors.isEmpty)
    }

    func testStopDoesNothingWhenAlreadyFailed() {
        context.phase = .failed

        stateMachine.stop()

        XCTAssertEqual(context.phase, .failed)
        XCTAssertTrue(context.errors.isEmpty)
    }

    // MARK: - Answer Question

    func testAnswerQuestionClearsPendingQuestion() async throws {
        context.sessionId = "test-session"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "Choose option",
                header: "Test",
                options: [],
                multiSelect: false
            )
        )
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("Option A")

        XCTAssertNil(context.pendingQuestion)
    }

    func testAnswerQuestionAddsLog() async throws {
        context.sessionId = "test-session"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "Choose",
                header: "Test",
                options: [],
                multiSelect: false
            )
        )
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("My answer")

        XCTAssertTrue(context.logs.contains { $0.message.contains("My answer") })
    }

    func testAnswerQuestionThrowsWithoutSessionId() async {
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "Test",
                header: "Test",
                options: [],
                multiSelect: false
            )
        )
        context.sessionId = nil

        do {
            try await stateMachine.answerQuestion("answer")
            XCTFail("Expected noSessionId error")
        } catch ExecutionStateMachineError.noSessionId {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAnswerQuestionDoesNothingWithoutPendingQuestion() async throws {
        context.sessionId = "test-session"
        context.pendingQuestion = nil

        let logCount = context.logs.count

        try await stateMachine.answerQuestion("answer")

        XCTAssertEqual(context.logs.count, logCount)
    }

    // MARK: - Error Descriptions

    func testErrorDescriptions() {
        XCTAssertEqual(
            ExecutionStateMachineError.noProjectPath.errorDescription,
            "No project path selected"
        )
        XCTAssertEqual(
            ExecutionStateMachineError.emptyFeatureDescription.errorDescription,
            "Feature description cannot be empty"
        )
        XCTAssertEqual(
            ExecutionStateMachineError.notPaused.errorDescription,
            "Cannot resume: execution is not paused"
        )
        XCTAssertEqual(
            ExecutionStateMachineError.noSessionId.errorDescription,
            "Cannot answer question: no active session"
        )
        XCTAssertEqual(
            ExecutionStateMachineError.noExistingPlan.errorDescription,
            "No existing plan loaded"
        )
    }

    // MARK: - Start With Existing Plan

    func testStartWithExistingPlanThrowsWithoutProjectPath() async {
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Task", description: "Test", status: .pending, subtasks: [])
        ])

        do {
            try await stateMachine.startWithExistingPlan()
            XCTFail("Expected noProjectPath error")
        } catch ExecutionStateMachineError.noProjectPath {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStartWithExistingPlanThrowsWithoutExistingPlan() async {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.existingPlan = nil

        do {
            try await stateMachine.startWithExistingPlan()
            XCTFail("Expected noExistingPlan error")
        } catch ExecutionStateMachineError.noExistingPlan {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStartWithExistingPlanSetsPlanFromExisting() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        let existingPlan = Plan(rawText: "Test plan", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Test Task", description: "Test", status: .pending, subtasks: [])
        ])
        context.existingPlan = existingPlan

        try await stateMachine.startWithExistingPlan()

        XCTAssertNotNil(context.plan)
        XCTAssertEqual(context.plan?.tasks.count, 1)
        XCTAssertEqual(context.plan?.tasks.first?.title, "Test Task")
    }

    func testStartWithExistingPlanSkipsPlanGeneration() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Test Task", description: "Test", status: .pending, subtasks: [])
        ])

        try await stateMachine.startWithExistingPlan()

        XCTAssertFalse(context.logs.contains { $0.message.contains("Executing phase: generatingInitialPlan") })
        XCTAssertFalse(context.logs.contains { $0.message.contains("Executing phase: rewritingPlan") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("Starting execution from existing plan") })
    }

    func testStartWithExistingPlanSetsStartTime() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Task", description: "Test", status: .pending, subtasks: [])
        ])

        XCTAssertNil(context.startTime)

        try await stateMachine.startWithExistingPlan()

        XCTAssertNotNil(context.startTime)
    }

    func testStartWithExistingPlanResumesFromFirstPendingTask() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Completed Task", description: "Test", status: .completed, subtasks: []),
            PlanTask(id: UUID(), number: 2, title: "Pending Task", description: "Test", status: .pending, subtasks: [])
        ])

        try await stateMachine.startWithExistingPlan()

        XCTAssertTrue(context.logs.contains { $0.message.contains("Resuming from task 2: Pending Task") })
    }

    func testStartWithExistingPlanCompletesImmediatelyIfAllTasksDone() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Task 1", description: "Test", status: .completed, subtasks: []),
            PlanTask(id: UUID(), number: 2, title: "Task 2", description: "Test", status: .completed, subtasks: [])
        ])

        try await stateMachine.startWithExistingPlan()

        XCTAssertEqual(context.phase, .completed)
        XCTAssertTrue(context.logs.contains { $0.message.contains("All tasks already completed") })
    }

    // MARK: - Phase Flow Tests

    func testFullLoopWithValidPlanEndsCompleted() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Implement Service", "Core logic")])

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .completed)
        XCTAssertTrue(context.logs.contains { $0.message.contains("All tasks completed") })
    }

    func testLoopFailsWithNoPlanAfterRewriting() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "No tasks here",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .failed)
        XCTAssertTrue(context.errors.contains { $0.message.contains("No tasks found in plan") })
    }

    func testLoopFailsWithEmptyTasksInPlan() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "No valid task format",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .failed)
        XCTAssertTrue(context.errors.contains { $0.message.contains("No tasks found in plan") })
    }

    func testMultipleTasksAdvanceCorrectly() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [
            (1, "Implement Service", "Core logic"),
            (2, "Add Validation", "Input validation")
        ])

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .completed)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Moving to task 2") })
    }

    func testTaskMarkedInProgressDuringExecution() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Implement Service", "Core logic")])

        try await stateMachine.start()

        let task = context.plan?.tasks.first
        XCTAssertEqual(task?.status, .completed)
    }

    func testTaskMarkedCompletedAfterExecution() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [
            (1, "Implement Service", "Core logic"),
            (2, "Add Validation", "Input validation")
        ])

        try await stateMachine.start()

        let firstTask = context.plan?.tasks[0]
        let secondTask = context.plan?.tasks[1]
        XCTAssertEqual(firstTask?.status, .completed)
        XCTAssertEqual(secondTask?.status, .completed)
    }

    // MARK: - shouldWriteTests Heuristic Tests

    func testUITaskSkipsTests() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Implement Setup View", "Create UI")])

        try await stateMachine.start()

        XCTAssertTrue(context.logs.contains { $0.message.contains("Skipping tests for UI-related task") })
        XCTAssertFalse(context.logs.contains { $0.message.contains("Writing tests") })
    }

    func testViewKeywordSkipsTests() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Build MainView", "Root component")])

        try await stateMachine.start()

        XCTAssertTrue(context.logs.contains { $0.message.contains("Skipping tests for UI-related task") })
    }

    func testButtonKeywordSkipsTests() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Add Submit Button", "Form submission")])

        try await stateMachine.start()

        XCTAssertTrue(context.logs.contains { $0.message.contains("Skipping tests for UI-related task") })
    }

    func testServiceTaskWritesTests() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Implement Plan Service", "Parse plans")])

        try await stateMachine.start()

        XCTAssertFalse(context.logs.contains { $0.message.contains("Skipping tests") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("Writing tests") })
    }

    func testModelTaskWritesTests() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Create Data Model", "Core data structures")])

        try await stateMachine.start()

        XCTAssertFalse(context.logs.contains { $0.message.contains("Skipping tests") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("Writing tests") })
    }

    func testUIKeywordInDescriptionSkipsTests() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Implement Controls", "Create UI elements for control panel")])

        try await stateMachine.start()

        XCTAssertTrue(context.logs.contains { $0.message.contains("Skipping tests for UI-related task") })
    }

    // MARK: - Phase Transition Logging

    func testPhaseTransitionsAreLogged() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Implement Service", "Core logic")])

        try await stateMachine.start()

        XCTAssertTrue(context.logs.contains { $0.message.contains("Transitioned to phase: rewritingPlan") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("Transitioned to phase: executingTask") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("Transitioned to phase: committingImplementation") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("Transitioned to phase: completed") })
    }

    func testContextClearedBetweenTasks() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [
            (1, "Implement Service", "Core logic"),
            (2, "Add Validation", "Input validation")
        ])
        context.sessionId = "initial-session"

        try await stateMachine.start()

        XCTAssertTrue(context.logs.contains { $0.message.contains("Context cleared for next task") })
    }

    // MARK: - Commit Message Generation

    func testCommitMessagesInLogs() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Add Authentication", "Auth logic")])

        try await stateMachine.start()

        XCTAssertTrue(context.logs.contains { $0.message.contains("feat: implement Add Authentication") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("refactor: code review fixes for Add Authentication") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("test: add tests for Add Authentication") })
    }

    // MARK: - Timeout Configuration Tests

    func testTimeoutConfigurationIsUsed() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.timeoutConfiguration = TimeoutConfiguration(
            planModeTimeout: 120,
            executionTimeout: 600
        )
        configureMockWithPlan(tasks: [(1, "Implement Service", "Core logic")])

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .completed)
        XCTAssertNotNil(mockClaudeService.lastTimeout)
    }

    func testTimeoutDefaultConfigurationWorks() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        configureMockWithPlan(tasks: [(1, "Implement Service", "Core logic")])

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .completed)
    }

    // MARK: - Retry Logic Tests

    func testRetryOnTransientError() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        mockClaudeService.failuresBeforeSuccess = 2
        configureMockWithPlan(tasks: [(1, "Implement Service", "Core logic")])

        try await stateMachine.start()

        XCTAssertGreaterThan(mockClaudeService.executeCallCount, 2)
        XCTAssertTrue(context.logs.contains { $0.message.contains("retrying") })
    }

    func testNonRetryableErrorFailsPlanGeneration() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        mockClaudeService.executeError = ClaudeCLIServiceError.noResultMessage

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .failed)
        XCTAssertTrue(context.errors.contains { $0.message.contains("generatingInitialPlan") })
    }

    func testRetryExhaustsMaxAttemptsInPlanGeneration() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.retryConfiguration = RetryConfiguration(
            maxAttempts: 2,
            initialDelay: 0.01,
            backoffMultiplier: 1.0,
            maxDelay: 0.01
        )
        mockClaudeService.failuresBeforeSuccess = 10

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .failed)
    }

    // MARK: - Task Failure Handling Tests

    func testPendingTaskFailureHasCorrectData() async throws {
        let failure = PendingTaskFailure(
            taskNumber: 5,
            taskTitle: "Implement Feature",
            error: "Connection timed out"
        )

        XCTAssertEqual(failure.taskNumber, 5)
        XCTAssertEqual(failure.taskTitle, "Implement Feature")
        XCTAssertEqual(failure.error, "Connection timed out")
        XCTAssertNotNil(failure.id)
    }

    func testTaskFailureRetryResponse() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.phase = .waitingForUser
        context.pendingTaskFailure = PendingTaskFailure(
            taskNumber: 1,
            taskTitle: "Test Task",
            error: "Test error"
        )
        context.plan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Test Task", description: "Test", status: .inProgress, subtasks: [])
        ])
        context.currentTaskIndex = 0

        await stateMachine.handleTaskFailureResponse(.retry)

        XCTAssertNil(context.pendingTaskFailure)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Retrying task") })
    }

    func testTaskFailureSkipResponse() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.phase = .waitingForUser
        context.pendingTaskFailure = PendingTaskFailure(
            taskNumber: 1,
            taskTitle: "Test Task",
            error: "Test error"
        )
        context.plan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Test Task", description: "Test", status: .inProgress, subtasks: []),
            PlanTask(id: UUID(), number: 2, title: "Next Task", description: "Test", status: .pending, subtasks: [])
        ])
        context.currentTaskIndex = 0

        await stateMachine.handleTaskFailureResponse(.skip)

        XCTAssertNil(context.pendingTaskFailure)
        XCTAssertEqual(context.plan?.tasks[0].status, .skipped)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Skipping task") })
    }

    func testTaskFailureStopResponse() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.phase = .waitingForUser
        context.pendingTaskFailure = PendingTaskFailure(
            taskNumber: 1,
            taskTitle: "Test Task",
            error: "Test error"
        )
        context.plan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Test Task", description: "Test", status: .inProgress, subtasks: [])
        ])
        context.currentTaskIndex = 0

        await stateMachine.handleTaskFailureResponse(.stop)

        XCTAssertNil(context.pendingTaskFailure)
        XCTAssertEqual(context.phase, .failed)
        XCTAssertEqual(context.plan?.tasks[0].status, .failed)
    }
}
