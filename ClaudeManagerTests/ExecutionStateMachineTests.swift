import XCTest
@testable import ClaudeManager

@MainActor
final class ExecutionStateMachineTests: XCTestCase {

    private var context: ExecutionContext!
    private var claudeService: ClaudeCLIService!
    private var planService: PlanService!
    private var gitService: GitService!
    private var stateMachine: ExecutionStateMachine!

    override func setUp() async throws {
        try await super.setUp()
        context = ExecutionContext()
        claudeService = ClaudeCLIService()
        planService = PlanService()
        gitService = GitService()
        stateMachine = ExecutionStateMachine(
            context: context,
            claudeService: claudeService,
            planService: planService,
            gitService: gitService
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
    }
}
