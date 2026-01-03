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
}
