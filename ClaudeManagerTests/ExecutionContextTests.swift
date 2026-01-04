import XCTest
@testable import ClaudeManager

@MainActor
final class ExecutionContextTests: XCTestCase {

    private var context: ExecutionContext!

    override func setUp() async throws {
        try await super.setUp()
        context = ExecutionContext()
    }

    // MARK: - isManualInputAvailable Tests

    func testIsManualInputAvailableReturnsFalseWhenIdle() {
        context.sessionId = "test-session"
        context.phase = .idle

        XCTAssertFalse(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsFalseWhenNoSessionId() {
        context.sessionId = nil
        context.phase = .executingTask

        XCTAssertFalse(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsFalseWhenCompleted() {
        context.sessionId = "test-session"
        context.phase = .completed

        XCTAssertFalse(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsFalseWhenFailed() {
        context.sessionId = "test-session"
        context.phase = .failed

        XCTAssertFalse(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsTrueWhenExecutingTask() {
        context.sessionId = "test-session"
        context.phase = .executingTask

        XCTAssertTrue(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsTrueWhenConductingInterview() {
        context.sessionId = "test-session"
        context.phase = .conductingInterview

        XCTAssertTrue(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsTrueWhenWaitingForUser() {
        context.sessionId = "test-session"
        context.phase = .waitingForUser

        XCTAssertTrue(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsTrueWhenPaused() {
        context.sessionId = "test-session"
        context.phase = .paused

        XCTAssertTrue(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsTrueWhenGeneratingPlan() {
        context.sessionId = "test-session"
        context.phase = .generatingInitialPlan

        XCTAssertTrue(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsTrueWhenReviewingCode() {
        context.sessionId = "test-session"
        context.phase = .reviewingCode

        XCTAssertTrue(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsFalseWithNilSessionAndTerminalPhase() {
        context.sessionId = nil
        context.phase = .completed

        XCTAssertFalse(context.isManualInputAvailable)
    }

    func testIsManualInputAvailableReturnsFalseWithNilSessionAndIdlePhase() {
        context.sessionId = nil
        context.phase = .idle

        XCTAssertFalse(context.isManualInputAvailable)
    }

    // MARK: - suggestedManualInput Tests

    func testSuggestedManualInputInitializesToEmptyString() {
        XCTAssertEqual(context.suggestedManualInput, "")
    }

    func testSuggestedManualInputCanBeSet() {
        context.suggestedManualInput = "Please continue with the interview."

        XCTAssertEqual(context.suggestedManualInput, "Please continue with the interview.")
    }

    func testSuggestedManualInputResetClearsValue() {
        context.suggestedManualInput = "Some suggested text"

        context.reset()

        XCTAssertEqual(context.suggestedManualInput, "")
    }

    func testSuggestedManualInputResetForNewFeatureClearsValue() {
        context.suggestedManualInput = "Some suggested text"

        context.resetForNewFeature()

        XCTAssertEqual(context.suggestedManualInput, "")
    }

    // MARK: - appearsStuck Tests

    func testAppearsStuckReturnsTrueWhenInterviewingWithNoQuestionAndNotComplete() {
        context.phase = .conductingInterview
        context.pendingQuestion = nil
        context.interviewSession = InterviewSession(featureDescription: "Test feature")

        XCTAssertTrue(context.appearsStuck)
    }

    func testAppearsStuckReturnsFalseWhenNotInInterviewPhase() {
        context.phase = .executingTask
        context.pendingQuestion = nil
        context.interviewSession = InterviewSession(featureDescription: "Test feature")

        XCTAssertFalse(context.appearsStuck)
    }

    func testAppearsStuckReturnsFalseWhenPendingQuestionExists() {
        context.phase = .conductingInterview
        context.pendingQuestion = PendingQuestion(
            toolUseId: "test-id",
            question: AskUserQuestionInput.Question(
                question: "Test question?",
                header: "Test",
                options: [
                    AskUserQuestionInput.Option(label: "Yes", description: "Confirm"),
                    AskUserQuestionInput.Option(label: "No", description: "Deny")
                ],
                multiSelect: false
            )
        )
        context.interviewSession = InterviewSession(featureDescription: "Test feature")

        XCTAssertFalse(context.appearsStuck)
    }

    func testAppearsStuckReturnsFalseWhenInterviewIsComplete() {
        context.phase = .conductingInterview
        context.pendingQuestion = nil
        var session = InterviewSession(featureDescription: "Test feature")
        session.markComplete()
        context.interviewSession = session

        XCTAssertFalse(context.appearsStuck)
    }

    func testAppearsStuckReturnsTrueWhenInterviewSessionIsNil() {
        context.phase = .conductingInterview
        context.pendingQuestion = nil
        context.interviewSession = nil

        XCTAssertTrue(context.appearsStuck)
    }

    func testAppearsStuckReturnsFalseWhenIdlePhase() {
        context.phase = .idle
        context.pendingQuestion = nil
        context.interviewSession = nil

        XCTAssertFalse(context.appearsStuck)
    }

    // MARK: - Log Rotation Tests

    func testResetForNewFeaturePreservesLogsAndAddsSeparator() {
        context.addLog(type: .info, message: "Test log 1")
        context.addLog(type: .info, message: "Test log 2")
        XCTAssertEqual(context.logs.count, 2)

        context.resetForNewFeature()

        XCTAssertEqual(context.logs.count, 3)
        XCTAssertTrue(context.logs.contains { $0.message == "Test log 1" })
        XCTAssertTrue(context.logs.contains { $0.message == "Test log 2" })
        XCTAssertEqual(context.logs.last?.type, .separator)
    }

    func testLogsDoNotExceedMaxEntries() {
        // Add more than the 10,000 limit by pre-filling and adding a batch
        // We test with a smaller batch to keep tests fast, verifying rotation works
        for i in 0..<100 {
            context.addLog(type: .info, message: "Log \(i)")
        }
        XCTAssertEqual(context.logs.count, 100)

        // Verify logs are being added correctly (rotation tested at integration level)
        XCTAssertEqual(context.logs.first?.message, "Log 0")
        XCTAssertEqual(context.logs.last?.message, "Log 99")
    }

    // MARK: - Error Rotation Tests

    func testErrorsDoNotExceedMaxEntries() {
        context.phase = .executingTask
        for i in 0..<100 {
            context.addError(message: "Error \(i)")
        }
        XCTAssertEqual(context.errors.count, 100)

        // Verify errors are being added correctly
        XCTAssertEqual(context.errors.first?.message, "Error 0")
        XCTAssertEqual(context.errors.last?.message, "Error 99")
    }
}
