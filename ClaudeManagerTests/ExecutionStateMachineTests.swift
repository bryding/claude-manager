import XCTest
@testable import ClaudeManager

@MainActor
final class ExecutionStateMachineTests: XCTestCase {

    private var context: ExecutionContext!
    private var mockClaudeService: MockClaudeCLIService!
    private var planService: PlanService!
    private var mockGitService: MockGitService!
    private var mockBuildTestService: MockBuildTestService!
    private var userPreferences: UserPreferences!
    private var stateMachine: ExecutionStateMachine!

    override func setUp() async throws {
        try await super.setUp()
        context = ExecutionContext()
        mockClaudeService = MockClaudeCLIService()
        planService = PlanService()
        mockGitService = MockGitService()
        mockBuildTestService = MockBuildTestService()
        userPreferences = UserPreferences()
        stateMachine = ExecutionStateMachine(
            context: context,
            claudeService: mockClaudeService,
            planService: planService,
            gitService: mockGitService,
            buildTestService: mockBuildTestService,
            userPreferences: userPreferences
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
        XCTAssertTrue(context.logs.contains { $0.message.contains("Starting feature interview") })
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

    func testAnswerQuestionWorksWithoutSessionId() async throws {
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

        try await stateMachine.answerQuestion("answer")

        XCTAssertNil(context.pendingQuestion)
        XCTAssertTrue(context.logs.contains { $0.message.contains("User answered: answer") })
    }

    func testAnswerQuestionDoesNothingWithoutPendingQuestion() async throws {
        context.sessionId = "test-session"
        context.pendingQuestion = nil

        let logCount = context.logs.count

        try await stateMachine.answerQuestion("answer")

        XCTAssertEqual(context.logs.count, logCount)
    }

    // MARK: - Question Queue Processing Tests

    func testAnswerQuestionShowsNextQueuedQuestion() async throws {
        context.sessionId = "test-session"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-1",
            question: AskUserQuestionInput.Question(
                question: "First question?",
                header: "Q1",
                options: [],
                multiSelect: false
            )
        )
        context.questionQueue = [
            PendingQuestion(
                toolUseId: "tool-2",
                question: AskUserQuestionInput.Question(
                    question: "Second question?",
                    header: "Q2",
                    options: [],
                    multiSelect: false
                )
            )
        ]
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("First answer")

        XCTAssertNotNil(context.pendingQuestion)
        XCTAssertEqual(context.pendingQuestion?.question.question, "Second question?")
        XCTAssertTrue(context.questionQueue.isEmpty)
        XCTAssertEqual(context.phase, .waitingForUser)
    }

    func testAnswerQuestionReturnsEarlyWithQueuedQuestions() async throws {
        context.sessionId = "test-session"
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-1",
            question: AskUserQuestionInput.Question(
                question: "First?",
                header: "Q1",
                options: [],
                multiSelect: false
            )
        )
        context.questionQueue = [
            PendingQuestion(
                toolUseId: "tool-2",
                question: AskUserQuestionInput.Question(
                    question: "Second?",
                    header: "Q2",
                    options: [],
                    multiSelect: false
                )
            )
        ]
        context.phase = .waitingForUser

        let executeCallsBefore = mockClaudeService.executeCallCount

        try await stateMachine.answerQuestion("Answer")

        XCTAssertEqual(mockClaudeService.executeCallCount, executeCallsBefore)
    }

    func testAnswerQuestionCallsRunLoopWhenQueueEmpty() async throws {
        context.sessionId = "test-session"
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.currentInterviewQuestion = "Only question?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-1",
            question: AskUserQuestionInput.Question(
                question: "Only question?",
                header: "Q",
                options: [],
                multiSelect: false
            )
        )
        context.questionQueue = []
        context.phase = .waitingForUser
        context.interviewSession = InterviewSession(featureDescription: "Test")

        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        let executeCallsBefore = mockClaudeService.executeCallCount

        try await stateMachine.answerQuestion("Answer")

        XCTAssertGreaterThan(mockClaudeService.executeCallCount, executeCallsBefore)
    }

    func testAnswerQuestionProcessesMultipleQueuedQuestions() async throws {
        context.sessionId = "test-session"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-1",
            question: AskUserQuestionInput.Question(
                question: "First?",
                header: "Q1",
                options: [],
                multiSelect: false
            )
        )
        context.questionQueue = [
            PendingQuestion(
                toolUseId: "tool-2",
                question: AskUserQuestionInput.Question(
                    question: "Second?",
                    header: "Q2",
                    options: [],
                    multiSelect: false
                )
            ),
            PendingQuestion(
                toolUseId: "tool-3",
                question: AskUserQuestionInput.Question(
                    question: "Third?",
                    header: "Q3",
                    options: [],
                    multiSelect: false
                )
            )
        ]
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("First answer")

        XCTAssertEqual(context.pendingQuestion?.question.question, "Second?")
        XCTAssertEqual(context.questionQueue.count, 1)
        XCTAssertEqual(context.questionQueue.first?.question.question, "Third?")

        try await stateMachine.answerQuestion("Second answer")

        XCTAssertEqual(context.pendingQuestion?.question.question, "Third?")
        XCTAssertTrue(context.questionQueue.isEmpty)
    }

    func testAnswerQuestionUsesInterviewModeForInterviewQuestion() async throws {
        context.sessionId = "test-session"
        context.interviewSession = InterviewSession(featureDescription: "Test")
        context.currentInterviewQuestion = "What is the scope?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-1",
            question: AskUserQuestionInput.Question(
                question: "What is the scope?",
                header: "Scope",
                options: [],
                multiSelect: false
            )
        )
        context.questionQueue = [
            PendingQuestion(
                toolUseId: "tool-2",
                question: AskUserQuestionInput.Question(
                    question: "Next interview question?",
                    header: "Next",
                    options: [],
                    multiSelect: false
                )
            )
        ]
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("Small scope")

        XCTAssertEqual(context.interviewSession?.exchanges.count, 1)
        XCTAssertEqual(context.pendingQuestion?.question.question, "Next interview question?")
        XCTAssertEqual(context.currentInterviewQuestion, "Next interview question?")
    }

    func testAnswerQuestionUsesStandardModeForNonInterviewQuestion() async throws {
        context.sessionId = "test-session"
        context.interviewSession = nil
        context.currentInterviewQuestion = nil
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-1",
            question: AskUserQuestionInput.Question(
                question: "Choose option?",
                header: "Choice",
                options: [],
                multiSelect: false
            )
        )
        context.questionQueue = [
            PendingQuestion(
                toolUseId: "tool-2",
                question: AskUserQuestionInput.Question(
                    question: "Another choice?",
                    header: "Choice2",
                    options: [],
                    multiSelect: false
                )
            )
        ]
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("Option A")

        XCTAssertEqual(context.pendingQuestion?.question.question, "Another choice?")
        XCTAssertNil(context.currentInterviewQuestion)
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
        context.retryConfiguration = RetryConfiguration(
            maxAttempts: 3,
            initialDelay: 0.01,
            backoffMultiplier: 1.0,
            maxDelay: 0.01
        )
        mockClaudeService.failuresBeforeSuccess = 2
        configureMockWithPlan(tasks: [(1, "Implement Service", "Core logic")])

        try await stateMachine.start()

        XCTAssertGreaterThan(mockClaudeService.executeCallCount, 2)
        XCTAssertTrue(context.logs.contains { $0.message.contains("retrying") })
    }

    func testNonRetryableErrorFailsInterview() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        mockClaudeService.executeError = ClaudeCLIServiceError.noResultMessage

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .failed)
        XCTAssertTrue(context.errors.contains { $0.message.contains("conductingInterview") })
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

    // MARK: - Autonomous Failure Handling Tests

    func testAutonomousRetryWhenUnderMaxRetries() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        userPreferences.autonomousConfig = AutonomousConfiguration(
            autoFailureHandling: .retryThenSkip,
            maxTaskRetries: 3
        )
        context.retryConfiguration = RetryConfiguration(
            maxAttempts: 1,
            initialDelay: 0.01,
            backoffMultiplier: 1.0,
            maxDelay: 0.01
        )
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Test Task", description: "Test", status: .pending, subtasks: [])
        ])
        // Fail twice, then succeed - autonomous retry should handle this
        mockClaudeService.failuresBeforeSuccess = 2

        try await stateMachine.startWithExistingPlan()

        XCTAssertEqual(context.phase, .completed)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Auto-retrying task") })
    }

    func testAutonomousRetryThenSkipWhenMaxRetriesExceeded() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        userPreferences.autonomousConfig = AutonomousConfiguration(
            autoFailureHandling: .retryThenSkip,
            maxTaskRetries: 2
        )
        context.retryConfiguration = RetryConfiguration(
            maxAttempts: 1,
            initialDelay: 0.01,
            backoffMultiplier: 1.0,
            maxDelay: 0.01
        )
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Failing Task", description: "Will fail", status: .pending, subtasks: []),
            PlanTask(id: UUID(), number: 2, title: "Next Task", description: "Should run after skip", status: .pending, subtasks: [])
        ])
        // Fail more than maxTaskRetries
        mockClaudeService.failuresBeforeSuccess = 10

        try await stateMachine.startWithExistingPlan()

        XCTAssertEqual(context.phase, .completed)
        XCTAssertEqual(context.plan?.tasks[0].status, .skipped)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Max retries exceeded, skipping task") })
    }

    func testAutonomousRetryThenStopWhenMaxRetriesExceeded() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        userPreferences.autonomousConfig = AutonomousConfiguration(
            autoFailureHandling: .retryThenStop,
            maxTaskRetries: 2
        )
        context.retryConfiguration = RetryConfiguration(
            maxAttempts: 1,
            initialDelay: 0.01,
            backoffMultiplier: 1.0,
            maxDelay: 0.01
        )
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Failing Task", description: "Will fail", status: .pending, subtasks: [])
        ])
        mockClaudeService.failuresBeforeSuccess = 10

        try await stateMachine.startWithExistingPlan()

        XCTAssertEqual(context.phase, .failed)
        XCTAssertEqual(context.plan?.tasks[0].status, .failed)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Max retries exceeded, stopping execution") })
    }

    func testAutonomousPauseForUserStillPausesOnFailure() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        userPreferences.autonomousConfig = AutonomousConfiguration(
            autoFailureHandling: .pauseForUser,
            maxTaskRetries: 3
        )
        context.retryConfiguration = RetryConfiguration(
            maxAttempts: 1,
            initialDelay: 0.01,
            backoffMultiplier: 1.0,
            maxDelay: 0.01
        )
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Failing Task", description: "Will fail", status: .pending, subtasks: [])
        ])
        mockClaudeService.failuresBeforeSuccess = 10

        try await stateMachine.startWithExistingPlan()

        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertNotNil(context.pendingTaskFailure)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Waiting for user input on task failure") })
    }

    func testTaskFailureCountResetsOnSuccess() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        userPreferences.autonomousConfig = AutonomousConfiguration(
            autoFailureHandling: .retryThenSkip,
            maxTaskRetries: 5
        )
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Test Task", description: "Test", status: .pending, subtasks: [])
        ])

        try await stateMachine.startWithExistingPlan()

        XCTAssertEqual(context.phase, .completed)
        XCTAssertEqual(context.taskFailureCount, 0)
    }

    func testTaskFailureCountIncrementsOnEachFailure() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        userPreferences.autonomousConfig = AutonomousConfiguration(
            autoFailureHandling: .retryThenSkip,
            maxTaskRetries: 3
        )
        context.retryConfiguration = RetryConfiguration(
            maxAttempts: 1,
            initialDelay: 0.01,
            backoffMultiplier: 1.0,
            maxDelay: 0.01
        )
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Failing Task", description: "Will fail", status: .pending, subtasks: []),
            PlanTask(id: UUID(), number: 2, title: "Next Task", description: "Runs after skip", status: .pending, subtasks: [])
        ])
        mockClaudeService.failuresBeforeSuccess = 10

        try await stateMachine.startWithExistingPlan()

        XCTAssertTrue(context.logs.contains { $0.message.contains("Task failure 1/3") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("Task failure 2/3") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("Task failure 3/3") })
    }

    // MARK: - Interview Initialization Tests

    func testStartInitializesInterviewSession() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a new authentication system"

        XCTAssertNil(context.interviewSession)

        try await stateMachine.start()

        XCTAssertNotNil(context.interviewSession)
        XCTAssertEqual(context.interviewSession?.featureDescription, "Build a new authentication system")
    }

    func testStartSetsInterviewPhase() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"

        try await stateMachine.start()

        XCTAssertTrue(context.logs.contains { $0.message.contains("Executing phase: conductingInterview") })
    }

    // MARK: - Reset Interview State Tests

    func testResetClearsInterviewSession() {
        context.interviewSession = InterviewSession(featureDescription: "Test feature")
        context.currentInterviewQuestion = "What is the scope?"

        context.reset()

        XCTAssertNil(context.interviewSession)
        XCTAssertNil(context.currentInterviewQuestion)
    }

    func testResetForNewFeatureClearsInterviewSession() {
        context.interviewSession = InterviewSession(featureDescription: "Test feature")
        context.currentInterviewQuestion = "What is the scope?"

        context.resetForNewFeature()

        XCTAssertNil(context.interviewSession)
        XCTAssertNil(context.currentInterviewQuestion)
    }

    func testResetForNewFeaturePreservesLogs() {
        context.addLog(type: .info, message: "Previous session log")
        context.interviewSession = InterviewSession(featureDescription: "Test feature")

        context.resetForNewFeature()

        XCTAssertFalse(context.logs.isEmpty)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Previous session log") })
    }

    func testResetClearsLogs() {
        context.addLog(type: .info, message: "Previous session log")
        context.interviewSession = InterviewSession(featureDescription: "Test feature")

        context.reset()

        XCTAssertTrue(context.logs.isEmpty)
    }

    // MARK: - INTERVIEW_COMPLETE Signal Tests

    func testInterviewCompleteSignalMarksSessionComplete() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        // Set up mock to send an assistant message containing INTERVIEW_COMPLETE
        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "The requirements are clear. INTERVIEW_COMPLETE")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "INTERVIEW_COMPLETE",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        XCTAssertTrue(context.interviewSession?.isComplete ?? false)
    }

    func testInterviewCompleteSignalWithSurroundingTextMarksComplete() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "I understand the requirements fully.\n\nINTERVIEW_COMPLETE\n\nProceeding to planning.")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "done",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        XCTAssertTrue(context.interviewSession?.isComplete ?? false)
    }

    func testInterviewWithoutCompleteSignalDoesNotMarkComplete() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        // Send an AskUserQuestion instead of INTERVIEW_COMPLETE
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What is the scope?", header: "Scope")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question asked",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        XCTAssertFalse(context.interviewSession?.isComplete ?? true)
        XCTAssertEqual(context.phase, .waitingForUser)
    }

    func testInterviewCompleteTransitionsToPlanGeneration() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "INTERVIEW_COMPLETE",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        // After interview completes, should transition to plan generation
        XCTAssertTrue(context.logs.contains { $0.message.contains("Interview completed, proceeding to plan generation") })
        XCTAssertTrue(context.logs.contains { $0.message.contains("Transitioned to phase: generatingInitialPlan") })
    }

    func testInterviewIncompleteStaysInInterviewPhase() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        // First call: Claude asks a question
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What is the scope?", header: "Scope")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question asked",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        // Should be waiting for user, interview not complete
        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertFalse(context.interviewSession?.isComplete ?? true)
        // Should NOT have transitioned to plan generation yet
        XCTAssertFalse(context.logs.contains { $0.message.contains("Transitioned to phase: generatingInitialPlan") })
    }

    func testInterviewAutoCompleteFallbackWhenNoQuestionAsked() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        // Claude responds with substantive text but no INTERVIEW_COMPLETE and no question
        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "I understand the requirements. This feature involves building a simple API endpoint.")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "substantive response without markers",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        // Auto-complete fallback should mark interview as complete
        XCTAssertTrue(context.interviewSession?.isComplete ?? false)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Claude responded without asking more questions, completing interview") })
    }

    // MARK: - Interview Answer Recording Tests

    func testAnswerQuestionRecordsInterviewAnswer() async throws {
        context.sessionId = "test-session"
        context.interviewSession = InterviewSession(featureDescription: "Build feature")
        context.currentInterviewQuestion = "What is the scope?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "What is the scope?",
                header: "Scope",
                options: [],
                multiSelect: false
            )
        )
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("Small scope, MVP only")

        XCTAssertEqual(context.interviewSession?.exchanges.count, 1)
        XCTAssertEqual(context.interviewSession?.exchanges.first?.question, "What is the scope?")
        XCTAssertEqual(context.interviewSession?.exchanges.first?.answer, "Small scope, MVP only")
    }

    func testAnswerQuestionClearsCurrentInterviewQuestion() async throws {
        context.sessionId = "test-session"
        context.interviewSession = InterviewSession(featureDescription: "Build feature")
        context.currentInterviewQuestion = "What is the scope?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "What is the scope?",
                header: "Scope",
                options: [],
                multiSelect: false
            )
        )
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("My answer")

        XCTAssertNil(context.currentInterviewQuestion)
    }

    func testAnswerQuestionSetsPhaseToInterview() async throws {
        context.sessionId = "test-session"
        context.interviewSession = InterviewSession(featureDescription: "Build feature")
        context.currentInterviewQuestion = "What is the scope?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "What is the scope?",
                header: "Scope",
                options: [],
                multiSelect: false
            )
        )
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("My answer")

        XCTAssertTrue(context.logs.contains { $0.message.contains("Executing phase: conductingInterview") })
    }

    func testAnswerQuestionDoesNotRecordWhenNoInterviewSession() async throws {
        context.sessionId = "test-session"
        context.interviewSession = nil
        context.currentInterviewQuestion = "What is the scope?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "Test",
                header: "Test",
                options: [],
                multiSelect: false
            )
        )
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("My answer")

        XCTAssertNil(context.interviewSession)
        XCTAssertEqual(context.currentInterviewQuestion, "What is the scope?")
    }

    func testAnswerQuestionDoesNotRecordWhenNoCurrentQuestion() async throws {
        context.sessionId = "test-session"
        context.interviewSession = InterviewSession(featureDescription: "Build feature")
        context.currentInterviewQuestion = nil
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "Test",
                header: "Test",
                options: [],
                multiSelect: false
            )
        )
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("My answer")

        XCTAssertEqual(context.interviewSession?.exchanges.count, 0)
    }

    func testAnswerQuestionDoesNotRecordWhenInterviewComplete() async throws {
        var session = InterviewSession(featureDescription: "Build feature")
        session.markComplete()
        context.sessionId = "test-session"
        context.interviewSession = session
        context.currentInterviewQuestion = "What is the scope?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "Test",
                header: "Test",
                options: [],
                multiSelect: false
            )
        )
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("My answer")

        XCTAssertEqual(context.interviewSession?.exchanges.count, 0)
        XCTAssertEqual(context.currentInterviewQuestion, "What is the scope?")
    }

    func testAnswerQuestionRecordsMultipleExchanges() async throws {
        context.sessionId = "test-session"
        var session = InterviewSession(featureDescription: "Build feature")
        session.addExchange(question: "First question?", answer: "First answer")
        context.interviewSession = session
        context.currentInterviewQuestion = "Second question?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "Second question?",
                header: "Q2",
                options: [],
                multiSelect: false
            )
        )
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("Second answer")

        XCTAssertEqual(context.interviewSession?.exchanges.count, 2)
        XCTAssertEqual(context.interviewSession?.exchanges[1].question, "Second question?")
        XCTAssertEqual(context.interviewSession?.exchanges[1].answer, "Second answer")
    }

    // MARK: - Interview Context in Plan Generation Tests

    func testPlanGenerationIncludesInterviewContext() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build authentication"

        var session = InterviewSession(featureDescription: "Build authentication")
        session.addExchange(question: "OAuth or JWT?", answer: "Use JWT")
        session.addExchange(question: "Session duration?", answer: "24 hours")
        session.markComplete()
        context.interviewSession = session

        context.phase = .generatingInitialPlan

        configureMockWithPlan(tasks: [(1, "Implement JWT", "Add JWT auth")])

        try await stateMachine.start()

        let planGenerationPrompt = mockClaudeService.allPrompts.first {
            $0.contains("Analyze the following feature request")
        }
        XCTAssertNotNil(planGenerationPrompt)
        XCTAssertTrue(planGenerationPrompt?.contains("## Clarifications from User") ?? false)
        XCTAssertTrue(planGenerationPrompt?.contains("Q1: OAuth or JWT?") ?? false)
        XCTAssertTrue(planGenerationPrompt?.contains("A1: Use JWT") ?? false)
        XCTAssertTrue(planGenerationPrompt?.contains("Q2: Session duration?") ?? false)
        XCTAssertTrue(planGenerationPrompt?.contains("A2: 24 hours") ?? false)
    }

    func testPlanGenerationOmitsClarificationsSectionWhenNoExchanges() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"

        var session = InterviewSession(featureDescription: "Build feature")
        session.markComplete()
        context.interviewSession = session

        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        try await stateMachine.start()

        let planGenerationPrompt = mockClaudeService.allPrompts.first {
            $0.contains("Analyze the following feature request")
        }
        XCTAssertNotNil(planGenerationPrompt)
        XCTAssertFalse(planGenerationPrompt?.contains("## Clarifications from User") ?? true)
    }

    func testPlanGenerationWorksWithoutInterviewSession() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.interviewSession = nil

        // Skip interview by using existing plan
        context.existingPlan = nil

        // Manually set up to go through plan generation without interview
        var session = InterviewSession(featureDescription: "Build feature")
        session.markComplete()
        context.interviewSession = session

        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        try await stateMachine.start()

        let planGenerationPrompt = mockClaudeService.allPrompts.first {
            $0.contains("Analyze the following feature request")
        }
        XCTAssertNotNil(planGenerationPrompt)
        XCTAssertFalse(planGenerationPrompt?.contains("## Clarifications from User") ?? true)
    }

    // MARK: - Question Asked During Phase Flag Tests

    func testInterviewQuestionBreaksLoopImmediately() async throws {
        // Arrange: Set up interview with a question
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What framework?", header: "Framework")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question asked",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        // Act
        try await stateMachine.start()

        // Assert: Loop should break after question, not transition to next phase
        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertFalse(context.logs.contains { $0.message.contains("Transitioned to phase: generatingInitialPlan") })
        XCTAssertEqual(mockClaudeService.executeCallCount, 1)
    }

    func testInterviewQuestionPreventsPhaseTransition() async throws {
        // Arrange
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What scope?", header: "Scope")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question asked",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        // Act
        try await stateMachine.start()

        // Assert: Should stay in interview-related state, not advance
        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertNotNil(context.pendingQuestion)
        XCTAssertEqual(context.currentInterviewQuestion, "What scope?")
    }

    func testMultipleInterviewQuestionsHandledSequentially() async throws {
        // Arrange: First question
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "First question?", header: "Q1")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "first question",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        // Act: Start interview
        try await stateMachine.start()

        // Assert: First question stops the loop
        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertEqual(context.currentInterviewQuestion, "First question?")
        let callCountAfterFirst = mockClaudeService.executeCallCount

        // Arrange: Set up second question for when user answers
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "Second question?", header: "Q2")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "second question",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        // Act: Answer first question
        try await stateMachine.answerQuestion("First answer")

        // Assert: Second question also stops the loop properly
        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertEqual(context.currentInterviewQuestion, "Second question?")
        XCTAssertEqual(mockClaudeService.executeCallCount, callCountAfterFirst + 1)
    }

    func testInterviewCompleteDoesNotBreakLoopPrematurely() async throws {
        // Arrange: Interview completes without question
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "I have all the information. INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        // Act
        try await stateMachine.start()

        // Assert: Should proceed through to completion (no question asked, so loop continues)
        XCTAssertEqual(context.phase, .completed)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Transitioned to phase: generatingInitialPlan") })
    }

    func testAnswerQuestionResumesLoopCorrectly() async throws {
        // Arrange: Start with a question
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What scope?", header: "Scope")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()
        XCTAssertEqual(context.phase, .waitingForUser)

        // Arrange: Set up completion response for after answer
        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "Got it. INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        // Act: Answer the question
        try await stateMachine.answerQuestion("Small scope")

        // Assert: Loop should resume and complete
        XCTAssertEqual(context.phase, .completed)
    }

    // MARK: - Test Helpers

    private func makeAssistantMessage(text: String) -> ClaudeStreamMessage {
        let json = """
        {
            "type": "assistant",
            "message": {
                "id": "msg_test",
                "model": "claude-opus-4-5-20251101",
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "\(escapeJSON(text))"}
                ],
                "stop_reason": null,
                "usage": {
                    "input_tokens": 100,
                    "output_tokens": 50
                }
            },
            "session_id": "mock-session-id",
            "parent_tool_use_id": null
        }
        """
        return try! JSONDecoder().decode(ClaudeStreamMessage.self, from: json.data(using: .utf8)!)
    }

    private func makeAskUserQuestionMessage(question: String, header: String) -> ClaudeStreamMessage {
        let json = """
        {
            "type": "assistant",
            "message": {
                "id": "msg_test",
                "model": "claude-opus-4-5-20251101",
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "toolu_ask",
                        "name": "AskUserQuestion",
                        "input": {
                            "questions": [
                                {
                                    "question": "\(escapeJSON(question))",
                                    "header": "\(escapeJSON(header))",
                                    "options": [
                                        {"label": "Option 1", "description": "First option"},
                                        {"label": "Option 2", "description": "Second option"}
                                    ],
                                    "multiSelect": false
                                }
                            ]
                        }
                    }
                ],
                "stop_reason": null,
                "usage": null
            },
            "session_id": "mock-session-id",
            "parent_tool_use_id": null
        }
        """
        return try! JSONDecoder().decode(ClaudeStreamMessage.self, from: json.data(using: .utf8)!)
    }

    private func escapeJSON(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    // MARK: - sendManualInput Tests

    func testSendManualInputThrowsWithoutProjectPath() async {
        context.sessionId = "test-session"
        context.projectPath = nil

        do {
            try await stateMachine.sendManualInput("test input")
            XCTFail("Expected noProjectPath error")
        } catch ExecutionStateMachineError.noProjectPath {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendManualInputThrowsWithoutSessionId() async {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = nil

        do {
            try await stateMachine.sendManualInput("test input")
            XCTFail("Expected noSessionId error")
        } catch ExecutionStateMachineError.noSessionId {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendManualInputLogsUserInput() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .executingTask
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "ok",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("my custom input")

        XCTAssertTrue(context.logs.contains { $0.message.contains("my custom input") })
    }

    func testSendManualInputUsesPlanModeForInterview() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .conductingInterview
        context.interviewSession = InterviewSession(featureDescription: "Test")
        // Return an AskUserQuestion to set phase to waitingForUser and prevent runLoop
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What next?", header: "Q")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "asked question",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("continue please")

        XCTAssertEqual(mockClaudeService.lastPermissionMode, .plan)
    }

    func testSendManualInputUsesAcceptEditsForTaskExecution() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .executingTask
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "ok",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("fix the bug")

        XCTAssertEqual(mockClaudeService.lastPermissionMode, .acceptEdits)
    }

    func testSendManualInputPassesSessionId() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "my-session-123"
        context.phase = .executingTask
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "ok",
            sessionId: "my-session-123",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("test")

        XCTAssertEqual(mockClaudeService.lastSessionId, "my-session-123")
    }

    func testSendManualInputThrowsOnError() async {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .executingTask
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "error",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: true
        )

        do {
            try await stateMachine.sendManualInput("test")
            XCTFail("Expected executionFailed error")
        } catch ExecutionStateMachineError.executionFailed(let phase) {
            XCTAssertEqual(phase, "sendManualInput")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendManualInputLogsSuccessMessage() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .executingTask
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "ok",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("test")

        XCTAssertTrue(context.logs.contains { $0.message.contains("Manual input processed successfully") })
    }

    func testSendManualInputUsesPlanModeForPlanGeneration() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .generatingInitialPlan
        // Return an AskUserQuestion to set phase to waitingForUser and prevent runLoop
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What next?", header: "Q")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "asked question",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("add more detail")

        XCTAssertEqual(mockClaudeService.lastPermissionMode, .plan)
    }

    func testSendManualInputUsesPlanModeForRewriting() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .rewritingPlan
        // Return an AskUserQuestion to set phase to waitingForUser and prevent runLoop
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What next?", header: "Q")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "asked question",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("restructure tasks")

        XCTAssertEqual(mockClaudeService.lastPermissionMode, .plan)
    }

    func testSendManualInputUsesAcceptEditsForCodeReview() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .reviewingCode
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "ok",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("focus on error handling")

        XCTAssertEqual(mockClaudeService.lastPermissionMode, .acceptEdits)
    }

    func testSendManualInputDoesNotResumeLoopWhenWaitingForUser() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .executingTask

        // Set up mock to trigger waitingForUser via AskUserQuestion
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "Which option?", header: "Choice")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question asked",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("proceed")

        // Phase should be waitingForUser, loop should not have advanced further
        XCTAssertEqual(context.phase, .waitingForUser)
    }

    func testSendManualInputDoesNotResumeLoopWhenTerminal() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .completed
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "ok",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        let logCountBefore = context.logs.count

        try await stateMachine.sendManualInput("test")

        // Should log input and success, but not execute any phase
        XCTAssertEqual(context.phase, .completed)
        XCTAssertFalse(context.logs.suffix(from: logCountBefore).contains { $0.message.contains("Executing phase:") })
    }

    func testSendManualInputHandlesInterviewMessages() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .conductingInterview
        context.interviewSession = InterviewSession(featureDescription: "Test feature")

        // Send a message that would complete the interview
        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "Got it. INTERVIEW_COMPLETE")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "INTERVIEW_COMPLETE",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("please continue")

        XCTAssertTrue(context.interviewSession?.isComplete ?? false)
    }

    func testSendManualInputHandlesInterviewQuestion() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .conductingInterview
        context.interviewSession = InterviewSession(featureDescription: "Test feature")

        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What framework?", header: "Framework")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("continue with interview")

        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertEqual(context.currentInterviewQuestion, "What framework?")
    }

    func testSendManualInputPassesPromptToService() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .executingTask
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "ok",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("please fix the authentication bug")

        XCTAssertEqual(mockClaudeService.lastPrompt, "please fix the authentication bug")
    }

    func testSendManualInputWithEmptyString() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .executingTask
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "ok",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.sendManualInput("")

        XCTAssertEqual(mockClaudeService.lastPrompt, "")
        XCTAssertTrue(context.logs.contains { $0.message == "User input: " })
    }

    func testSendManualInputLogsErrorOnFailure() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.phase = .executingTask
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "error",
            sessionId: "test-session",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: true
        )

        do {
            try await stateMachine.sendManualInput("test")
        } catch {
            // Expected
        }

        XCTAssertTrue(context.logs.contains { $0.message.contains("Manual input execution failed") })
    }

    // MARK: - Image Support Tests

    private func makeTestImage(mediaType: ImageMediaType = .png) -> AttachedImage {
        let data = Data(repeating: 0x42, count: 100)
        let thumbnail = NSImage(size: NSSize(width: 80, height: 80))
        return AttachedImage(
            data: data,
            mediaType: mediaType,
            thumbnail: thumbnail,
            originalSize: CGSize(width: 800, height: 600)
        )
    }

    // MARK: - start() Image Tests

    func testStartPassesAttachedImagesToInterviewSession() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature with image reference"
        let image = makeTestImage()
        context.attachedImages = [image]

        try await stateMachine.start()

        XCTAssertEqual(context.interviewSession?.attachedImages.count, 1)
        XCTAssertEqual(context.interviewSession?.attachedImages.first?.id, image.id)
    }

    func testStartPassesMultipleImagesToInterviewSession() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        let image1 = makeTestImage()
        let image2 = makeTestImage(mediaType: .jpeg)
        context.attachedImages = [image1, image2]

        try await stateMachine.start()

        XCTAssertEqual(context.interviewSession?.attachedImages.count, 2)
    }

    func testStartWithNoImagesCreatesSessionWithEmptyImages() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.attachedImages = []

        try await stateMachine.start()

        XCTAssertNotNil(context.interviewSession)
        XCTAssertTrue(context.interviewSession?.attachedImages.isEmpty ?? false)
    }

    // MARK: - conductInterview() Image Tests

    func testConductInterviewIncludesImagesOnFirstCall() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        let image = makeTestImage()
        context.attachedImages = [image]

        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        try await stateMachine.start()

        let firstContent = mockClaudeService.allContents.first
        XCTAssertNotNil(firstContent)
        XCTAssertEqual(firstContent?.images.count, 1)
        XCTAssertEqual(firstContent?.images.first?.id, image.id)
    }

    func testConductInterviewDoesNotIncludeImagesOnSubsequentCalls() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        let image = makeTestImage()
        context.attachedImages = [image]

        // First call: ask a question
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What scope?", header: "Scope")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .waitingForUser)
        let firstContent = mockClaudeService.allContents.first
        XCTAssertEqual(firstContent?.images.count, 1)

        // Clear to prepare for second call
        mockClaudeService.allContents.removeAll()
        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        // Answer the question (triggers second interview call)
        try await stateMachine.answerQuestion("Small scope")

        // Second call should have empty images
        let secondContent = mockClaudeService.allContents.first
        XCTAssertNotNil(secondContent)
        XCTAssertTrue(secondContent?.images.isEmpty ?? false)
    }

    func testConductInterviewDoesNotResumeSessionForSubsequentCalls() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"

        // First call: ask a question (returns a session ID)
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What scope?", header: "Scope")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question",
            sessionId: "interview-session-1",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .waitingForUser)
        // First interview call should have nil sessionId (fresh session)
        XCTAssertEqual(mockClaudeService.allSessionIds.count, 1)
        XCTAssertNil(mockClaudeService.allSessionIds[0])

        // Prepare for second call
        mockClaudeService.allSessionIds.removeAll()
        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        // Answer the question (triggers second interview call)
        try await stateMachine.answerQuestion("Small scope")

        // Second interview call should also have nil sessionId (not resuming)
        // to avoid tool result confusion since previous Q&A is in prompt text
        XCTAssertGreaterThanOrEqual(mockClaudeService.allSessionIds.count, 1)
        XCTAssertNil(mockClaudeService.allSessionIds[0])
    }

    func testConductInterviewWithNoImagesUsesEmptyContent() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.attachedImages = []

        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        try await stateMachine.start()

        let firstContent = mockClaudeService.allContents.first
        XCTAssertNotNil(firstContent)
        XCTAssertTrue(firstContent?.images.isEmpty ?? false)
    }

    // MARK: - generateInitialPlan() Image Tests

    func testGenerateInitialPlanIncludesImagesFromSession() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        let image = makeTestImage()
        context.attachedImages = [image]

        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        try await stateMachine.start()

        // Find the plan generation call (contains "Analyze the following feature request")
        let planGenerationContent = mockClaudeService.allContents.first {
            $0.text.contains("Analyze the following feature request")
        }
        XCTAssertNotNil(planGenerationContent)
        XCTAssertEqual(planGenerationContent?.images.count, 1)
        XCTAssertEqual(planGenerationContent?.images.first?.id, image.id)
    }

    func testGenerateInitialPlanWithMultipleImages() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        let image1 = makeTestImage()
        let image2 = makeTestImage(mediaType: .jpeg)
        context.attachedImages = [image1, image2]

        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        try await stateMachine.start()

        let planGenerationContent = mockClaudeService.allContents.first {
            $0.text.contains("Analyze the following feature request")
        }
        XCTAssertNotNil(planGenerationContent)
        XCTAssertEqual(planGenerationContent?.images.count, 2)
    }

    func testGenerateInitialPlanWithNoImagesHasEmptyImages() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.attachedImages = []

        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        try await stateMachine.start()

        let planGenerationContent = mockClaudeService.allContents.first {
            $0.text.contains("Analyze the following feature request")
        }
        XCTAssertNotNil(planGenerationContent)
        XCTAssertTrue(planGenerationContent?.images.isEmpty ?? false)
    }

    func testImagesArePreservedInInterviewSession() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        let image = makeTestImage()
        context.attachedImages = [image]

        // First call: ask question
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What scope?", header: "Scope")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        // Verify the interview session preserved the image
        XCTAssertEqual(context.interviewSession?.attachedImages.count, 1)
        XCTAssertEqual(context.interviewSession?.attachedImages.first?.id, image.id)

        // Verify first interview call included the image
        let firstContent = mockClaudeService.allContents.first
        XCTAssertNotNil(firstContent)
        XCTAssertEqual(firstContent?.images.count, 1)
        XCTAssertEqual(firstContent?.images.first?.id, image.id)
    }

    func testStartWithExistingPlanDoesNotUseImages() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        let image = makeTestImage()
        context.attachedImages = [image]
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Test Task", description: "Test", status: .pending, subtasks: [])
        ])

        try await stateMachine.startWithExistingPlan()

        // Should not have any content with images since we skip interview and planning
        let contentsWithImages = mockClaudeService.allContents.filter { !$0.images.isEmpty }
        XCTAssertTrue(contentsWithImages.isEmpty)
    }

    // MARK: - Question Queue Tests

    func testMultipleQuestionsInSingleMessageAreQueued() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessageWithMultipleQuestions([
                (question: "What framework?", header: "Framework"),
                (question: "What database?", header: "Database"),
                (question: "What auth method?", header: "Auth")
            ])
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "questions asked",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        // First question should be displayed, remaining 2 should be in queue
        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertNotNil(context.pendingQuestion)
        XCTAssertEqual(context.pendingQuestion?.question.header, "Framework")
        XCTAssertEqual(context.questionQueue.count, 2)
        XCTAssertEqual(context.questionQueue[0].question.header, "Database")
        XCTAssertEqual(context.questionQueue[1].question.header, "Auth")
    }

    func testAnsweringQuestionShowsNextFromQueue() async throws {
        context.sessionId = "test-session"
        context.interviewSession = InterviewSession(featureDescription: "Build feature")
        context.currentInterviewQuestion = "What framework?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "What framework?",
                header: "Framework",
                options: [
                    AskUserQuestionInput.Option(label: "React", description: "React framework"),
                    AskUserQuestionInput.Option(label: "Vue", description: "Vue framework")
                ],
                multiSelect: false
            )
        )
        // Queue remaining questions
        context.questionQueue = [
            PendingQuestion(
                toolUseId: "tool-123",
                question: AskUserQuestionInput.Question(
                    question: "What database?",
                    header: "Database",
                    options: [
                        AskUserQuestionInput.Option(label: "PostgreSQL", description: "Postgres"),
                        AskUserQuestionInput.Option(label: "MySQL", description: "MySQL")
                    ],
                    multiSelect: false
                )
            ),
            PendingQuestion(
                toolUseId: "tool-123",
                question: AskUserQuestionInput.Question(
                    question: "What auth?",
                    header: "Auth",
                    options: [
                        AskUserQuestionInput.Option(label: "JWT", description: "JWT auth"),
                        AskUserQuestionInput.Option(label: "Session", description: "Session auth")
                    ],
                    multiSelect: false
                )
            )
        ]
        context.phase = .waitingForUser

        try await stateMachine.answerQuestion("React")

        // Should show next question from queue without calling Claude
        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertNotNil(context.pendingQuestion)
        XCTAssertEqual(context.pendingQuestion?.question.header, "Database")
        XCTAssertEqual(context.questionQueue.count, 1)
        XCTAssertEqual(context.questionQueue[0].question.header, "Auth")
        // The interview exchange should be recorded
        XCTAssertEqual(context.interviewSession?.exchanges.count, 1)
        XCTAssertEqual(context.interviewSession?.exchanges.first?.question, "What framework?")
        XCTAssertEqual(context.interviewSession?.exchanges.first?.answer, "React")
    }

    func testAllQARecordedInInterviewSession() async throws {
        context.sessionId = "test-session"
        let session = InterviewSession(featureDescription: "Build feature")
        context.interviewSession = session

        // Set up first question
        context.currentInterviewQuestion = "Q1?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "Q1?",
                header: "Q1",
                options: [
                    AskUserQuestionInput.Option(label: "A", description: "Option A"),
                    AskUserQuestionInput.Option(label: "B", description: "Option B")
                ],
                multiSelect: false
            )
        )
        context.questionQueue = [
            PendingQuestion(
                toolUseId: "tool-123",
                question: AskUserQuestionInput.Question(
                    question: "Q2?",
                    header: "Q2",
                    options: [
                        AskUserQuestionInput.Option(label: "C", description: "Option C"),
                        AskUserQuestionInput.Option(label: "D", description: "Option D")
                    ],
                    multiSelect: false
                )
            ),
            PendingQuestion(
                toolUseId: "tool-123",
                question: AskUserQuestionInput.Question(
                    question: "Q3?",
                    header: "Q3",
                    options: [
                        AskUserQuestionInput.Option(label: "E", description: "Option E"),
                        AskUserQuestionInput.Option(label: "F", description: "Option F")
                    ],
                    multiSelect: false
                )
            )
        ]
        context.phase = .waitingForUser

        // Answer first question
        try await stateMachine.answerQuestion("Answer 1")

        // currentInterviewQuestion should now be Q2
        XCTAssertEqual(context.currentInterviewQuestion, "Q2?")
        XCTAssertEqual(context.interviewSession?.exchanges.count, 1)

        // Answer second question
        try await stateMachine.answerQuestion("Answer 2")

        XCTAssertEqual(context.currentInterviewQuestion, "Q3?")
        XCTAssertEqual(context.interviewSession?.exchanges.count, 2)

        // Set up mock for when queue is empty (will resume loop)
        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        // Answer third (last) question
        try await stateMachine.answerQuestion("Answer 3")

        // All three Q&A pairs should be recorded
        XCTAssertEqual(context.interviewSession?.exchanges.count, 3)
        XCTAssertEqual(context.interviewSession?.exchanges[0].question, "Q1?")
        XCTAssertEqual(context.interviewSession?.exchanges[0].answer, "Answer 1")
        XCTAssertEqual(context.interviewSession?.exchanges[1].question, "Q2?")
        XCTAssertEqual(context.interviewSession?.exchanges[1].answer, "Answer 2")
        XCTAssertEqual(context.interviewSession?.exchanges[2].question, "Q3?")
        XCTAssertEqual(context.interviewSession?.exchanges[2].answer, "Answer 3")
    }

    func testEmptyQueueResumesMainLoop() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.sessionId = "test-session"
        context.interviewSession = InterviewSession(featureDescription: "Build feature")
        context.currentInterviewQuestion = "Final question?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "Final question?",
                header: "Final",
                options: [
                    AskUserQuestionInput.Option(label: "Yes", description: "Confirm"),
                    AskUserQuestionInput.Option(label: "No", description: "Deny")
                ],
                multiSelect: false
            )
        )
        context.questionQueue = [] // Empty queue
        context.phase = .waitingForUser

        // Set up mock to complete interview when loop resumes
        mockClaudeService.messagesToSend = [
            makeAssistantMessage(text: "INTERVIEW_COMPLETE")
        ]
        configureMockWithPlan(tasks: [(1, "Task", "Description")])

        try await stateMachine.answerQuestion("Yes")

        // Should have resumed loop and completed
        XCTAssertEqual(context.phase, .completed)
        XCTAssertTrue(context.logs.contains { $0.message.contains("Executing phase: conductingInterview") })
    }

    func testSingleQuestionDoesNotCreateQueue() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessage(question: "What framework?", header: "Framework")
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "question asked",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertNotNil(context.pendingQuestion)
        XCTAssertTrue(context.questionQueue.isEmpty)
    }

    func testAnswerQuestionWithQueueDoesNotCallClaude() async throws {
        context.sessionId = "test-session"
        context.interviewSession = InterviewSession(featureDescription: "Build feature")
        context.currentInterviewQuestion = "Q1?"
        context.pendingQuestion = PendingQuestion(
            toolUseId: "tool-123",
            question: AskUserQuestionInput.Question(
                question: "Q1?",
                header: "Q1",
                options: [
                    AskUserQuestionInput.Option(label: "A", description: "A"),
                    AskUserQuestionInput.Option(label: "B", description: "B")
                ],
                multiSelect: false
            )
        )
        context.questionQueue = [
            PendingQuestion(
                toolUseId: "tool-123",
                question: AskUserQuestionInput.Question(
                    question: "Q2?",
                    header: "Q2",
                    options: [
                        AskUserQuestionInput.Option(label: "C", description: "C"),
                        AskUserQuestionInput.Option(label: "D", description: "D")
                    ],
                    multiSelect: false
                )
            )
        ]
        context.phase = .waitingForUser

        let callCountBefore = mockClaudeService.executeCallCount

        try await stateMachine.answerQuestion("A")

        // Should NOT have called Claude since there's another question in queue
        XCTAssertEqual(mockClaudeService.executeCallCount, callCountBefore)
        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertNotNil(context.pendingQuestion)
    }

    func testQuestionQueuePreservesToolUseId() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build a feature"

        let toolId = "unique-tool-id-12345"
        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessageWithMultipleQuestionsAndToolId(
                toolId: toolId,
                questions: [
                    (question: "Q1?", header: "Q1"),
                    (question: "Q2?", header: "Q2")
                ]
            )
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "questions asked",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.start()

        // Both questions should have the same tool use ID
        XCTAssertEqual(context.pendingQuestion?.toolUseId, toolId)
        XCTAssertEqual(context.questionQueue.first?.toolUseId, toolId)
    }

    func testQuestionQueueWithStandardModeQuestion() async throws {
        context.projectPath = URL(fileURLWithPath: "/tmp/project")
        context.featureDescription = "Build feature"
        context.existingPlan = Plan(rawText: "", tasks: [
            PlanTask(id: UUID(), number: 1, title: "Test Task", description: "Test", status: .pending, subtasks: [])
        ])

        // Configure auto-answer to be disabled for standard mode questions
        userPreferences.autonomousConfig = AutonomousConfiguration(
            autoAnswerEnabled: false
        )

        mockClaudeService.messagesToSend = [
            makeAskUserQuestionMessageWithMultipleQuestions([
                (question: "Which approach?", header: "Approach"),
                (question: "Which library?", header: "Library")
            ])
        ]
        mockClaudeService.executeResult = ClaudeExecutionResult(
            result: "questions",
            sessionId: "mock-session-id",
            totalCostUsd: 0.0,
            durationMs: 100,
            isError: false
        )

        try await stateMachine.startWithExistingPlan()

        // Should pause for standard mode questions with queue
        XCTAssertEqual(context.phase, .waitingForUser)
        XCTAssertNotNil(context.pendingQuestion)
        XCTAssertEqual(context.questionQueue.count, 1)
    }

    // MARK: - Additional Test Helpers

    private func makeAskUserQuestionMessageWithMultipleQuestions(
        _ questions: [(question: String, header: String)]
    ) -> ClaudeStreamMessage {
        makeAskUserQuestionMessageWithMultipleQuestionsAndToolId(
            toolId: "toolu_multi",
            questions: questions
        )
    }

    private func makeAskUserQuestionMessageWithMultipleQuestionsAndToolId(
        toolId: String,
        questions: [(question: String, header: String)]
    ) -> ClaudeStreamMessage {
        let questionsJSON = questions.map { q in
            """
            {
                "question": "\(escapeJSON(q.question))",
                "header": "\(escapeJSON(q.header))",
                "options": [
                    {"label": "Option 1", "description": "First option"},
                    {"label": "Option 2", "description": "Second option"}
                ],
                "multiSelect": false
            }
            """
        }.joined(separator: ",\n")

        let json = """
        {
            "type": "assistant",
            "message": {
                "id": "msg_test",
                "model": "claude-opus-4-5-20251101",
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "\(toolId)",
                        "name": "AskUserQuestion",
                        "input": {
                            "questions": [
                                \(questionsJSON)
                            ]
                        }
                    }
                ],
                "stop_reason": null,
                "usage": null
            },
            "session_id": "mock-session-id",
            "parent_tool_use_id": null
        }
        """
        return try! JSONDecoder().decode(ClaudeStreamMessage.self, from: json.data(using: .utf8)!)
    }
}
