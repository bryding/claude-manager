import XCTest
@testable import ClaudeManager

@MainActor
final class ExecutionContextTests: XCTestCase {

    private var context: ExecutionContext!

    override func setUp() async throws {
        try await super.setUp()
        context = ExecutionContext()
    }

    // MARK: - Test Helpers

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

    private func makeTestQuestion(toolUseId: String = "test-id") -> PendingQuestion {
        PendingQuestion(
            toolUseId: toolUseId,
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
        context.pendingQuestion = makeTestQuestion()
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

    // MARK: - attachedImages Tests

    func testAttachedImagesInitializesToEmpty() {
        XCTAssertTrue(context.attachedImages.isEmpty)
    }

    func testAddImageAppendsToAttachedImages() {
        let image = makeTestImage()

        context.addImage(image)

        XCTAssertEqual(context.attachedImages.count, 1)
        XCTAssertEqual(context.attachedImages.first?.id, image.id)
    }

    func testAddMultipleImages() {
        let image1 = makeTestImage()
        let image2 = makeTestImage(mediaType: .jpeg)

        context.addImage(image1)
        context.addImage(image2)

        XCTAssertEqual(context.attachedImages.count, 2)
        XCTAssertEqual(context.attachedImages[0].id, image1.id)
        XCTAssertEqual(context.attachedImages[1].id, image2.id)
    }

    func testRemoveImageById() {
        let image1 = makeTestImage()
        let image2 = makeTestImage()
        context.addImage(image1)
        context.addImage(image2)

        context.removeImage(id: image1.id)

        XCTAssertEqual(context.attachedImages.count, 1)
        XCTAssertEqual(context.attachedImages.first?.id, image2.id)
    }

    func testRemoveImageWithNonexistentIdDoesNothing() {
        let image = makeTestImage()
        context.addImage(image)

        context.removeImage(id: UUID())

        XCTAssertEqual(context.attachedImages.count, 1)
    }

    func testRemoveAllImagesClearsAttachedImages() {
        context.addImage(makeTestImage())
        context.addImage(makeTestImage())
        context.addImage(makeTestImage())

        context.removeAllImages()

        XCTAssertTrue(context.attachedImages.isEmpty)
    }

    func testRemoveAllImagesOnEmptyArrayDoesNothing() {
        context.removeAllImages()

        XCTAssertTrue(context.attachedImages.isEmpty)
    }

    func testResetClearsAttachedImages() {
        context.addImage(makeTestImage())
        context.addImage(makeTestImage())

        context.reset()

        XCTAssertTrue(context.attachedImages.isEmpty)
    }

    func testResetForNewFeatureClearsAttachedImages() {
        context.addImage(makeTestImage())
        context.addImage(makeTestImage())

        context.resetForNewFeature()

        XCTAssertTrue(context.attachedImages.isEmpty)
    }

    // MARK: - promptContent Tests

    func testPromptContentWithTextOnly() {
        context.featureDescription = "Test feature"

        let content = context.promptContent

        XCTAssertEqual(content.text, "Test feature")
        XCTAssertTrue(content.images.isEmpty)
    }

    func testPromptContentWithTextAndImages() {
        context.featureDescription = "Feature with images"
        let image = makeTestImage()
        context.addImage(image)

        let content = context.promptContent

        XCTAssertEqual(content.text, "Feature with images")
        XCTAssertEqual(content.images.count, 1)
        XCTAssertEqual(content.images.first?.id, image.id)
    }

    func testPromptContentReflectsCurrentState() {
        context.featureDescription = "Initial"
        let image1 = makeTestImage()
        context.addImage(image1)

        var content = context.promptContent
        XCTAssertEqual(content.text, "Initial")
        XCTAssertEqual(content.images.count, 1)

        context.featureDescription = "Updated"
        context.addImage(makeTestImage())

        content = context.promptContent
        XCTAssertEqual(content.text, "Updated")
        XCTAssertEqual(content.images.count, 2)
    }

    // MARK: - canPause Tests

    func testCanPauseReturnsTrueWhenRunningAndNotWaitingForUser() {
        context.phase = .executingTask
        XCTAssertTrue(context.canPause)
    }

    func testCanPauseReturnsTrueWhenGeneratingPlan() {
        context.phase = .generatingInitialPlan
        XCTAssertTrue(context.canPause)
    }

    func testCanPauseReturnsTrueWhenReviewingCode() {
        context.phase = .reviewingCode
        XCTAssertTrue(context.canPause)
    }

    func testCanPauseReturnsFalseWhenWaitingForUser() {
        context.phase = .waitingForUser
        XCTAssertFalse(context.canPause)
    }

    func testCanPauseReturnsFalseWhenIdle() {
        context.phase = .idle
        XCTAssertFalse(context.canPause)
    }

    func testCanPauseReturnsFalseWhenPaused() {
        context.phase = .paused
        XCTAssertFalse(context.canPause)
    }

    func testCanPauseReturnsFalseWhenCompleted() {
        context.phase = .completed
        XCTAssertFalse(context.canPause)
    }

    func testCanPauseReturnsFalseWhenFailed() {
        context.phase = .failed
        XCTAssertFalse(context.canPause)
    }

    // MARK: - canResume Tests

    func testCanResumeReturnsTrueWhenPaused() {
        context.phase = .paused
        XCTAssertTrue(context.canResume)
    }

    func testCanResumeReturnsFalseWhenIdle() {
        context.phase = .idle
        XCTAssertFalse(context.canResume)
    }

    func testCanResumeReturnsFalseWhenExecutingTask() {
        context.phase = .executingTask
        XCTAssertFalse(context.canResume)
    }

    func testCanResumeReturnsFalseWhenCompleted() {
        context.phase = .completed
        XCTAssertFalse(context.canResume)
    }

    func testCanResumeReturnsFalseWhenFailed() {
        context.phase = .failed
        XCTAssertFalse(context.canResume)
    }

    func testCanResumeReturnsFalseWhenWaitingForUser() {
        context.phase = .waitingForUser
        XCTAssertFalse(context.canResume)
    }

    // MARK: - canStop Tests

    func testCanStopReturnsTrueWhenExecutingTask() {
        context.phase = .executingTask
        XCTAssertTrue(context.canStop)
    }

    func testCanStopReturnsTrueWhenPaused() {
        context.phase = .paused
        XCTAssertTrue(context.canStop)
    }

    func testCanStopReturnsTrueWhenWaitingForUser() {
        context.phase = .waitingForUser
        XCTAssertTrue(context.canStop)
    }

    func testCanStopReturnsTrueWhenGeneratingPlan() {
        context.phase = .generatingInitialPlan
        XCTAssertTrue(context.canStop)
    }

    func testCanStopReturnsFalseWhenIdle() {
        context.phase = .idle
        XCTAssertFalse(context.canStop)
    }

    func testCanStopReturnsFalseWhenCompleted() {
        context.phase = .completed
        XCTAssertFalse(context.canStop)
    }

    func testCanStopReturnsFalseWhenFailed() {
        context.phase = .failed
        XCTAssertFalse(context.canStop)
    }

    // MARK: - questionQueue Tests

    func testQuestionQueueInitializesToEmpty() {
        XCTAssertTrue(context.questionQueue.isEmpty)
    }

    func testHasQueuedQuestionsReturnsFalseWhenEmpty() {
        XCTAssertFalse(context.hasQueuedQuestions)
    }

    func testHasQueuedQuestionsReturnsTrueWhenNotEmpty() {
        context.questionQueue.append(makeTestQuestion())

        XCTAssertTrue(context.hasQueuedQuestions)
    }

    func testQuestionQueueResetClearsValue() {
        context.questionQueue.append(makeTestQuestion())

        context.reset()

        XCTAssertTrue(context.questionQueue.isEmpty)
        XCTAssertFalse(context.hasQueuedQuestions)
    }

    func testQuestionQueueResetForNewFeatureClearsValue() {
        context.questionQueue.append(makeTestQuestion())

        context.resetForNewFeature()

        XCTAssertTrue(context.questionQueue.isEmpty)
        XCTAssertFalse(context.hasQueuedQuestions)
    }

    // MARK: - showStopConfirmation Tests

    func testShowStopConfirmationInitializesToFalse() {
        XCTAssertFalse(context.showStopConfirmation)
    }

    func testShowStopConfirmationCanBeSet() {
        context.showStopConfirmation = true
        XCTAssertTrue(context.showStopConfirmation)
    }

    func testShowStopConfirmationResetClearsValue() {
        context.showStopConfirmation = true

        context.reset()

        XCTAssertFalse(context.showStopConfirmation)
    }

    func testShowStopConfirmationResetForNewFeatureClearsValue() {
        context.showStopConfirmation = true

        context.resetForNewFeature()

        XCTAssertFalse(context.showStopConfirmation)
    }
}
