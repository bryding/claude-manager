import XCTest
@testable import ClaudeManager

private actor MessageCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

final class ClaudeCLIServiceProtocolTests: XCTestCase {

    private var tempDirectory: URL!
    private var mockService: MockClaudeCLIService!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        mockService = MockClaudeCLIService()
    }

    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        mockService = nil
        try await super.tearDown()
    }

    // MARK: - Test Helpers

    private func makeTestImage() -> AttachedImage {
        let data = Data(repeating: 0x42, count: 100)
        let thumbnail = NSImage(size: NSSize(width: 80, height: 80))
        return AttachedImage(
            data: data,
            mediaType: .png,
            thumbnail: thumbnail,
            originalSize: CGSize(width: 800, height: 600)
        )
    }

    // MARK: - Convenience Method Tests (prompt without timeout)

    func testExecutePromptWithoutTimeoutDelegatesToFullMethod() async throws {
        mockService.executeResult = ClaudeExecutionResult(
            result: "Success",
            sessionId: "session-123",
            totalCostUsd: 0.01,
            durationMs: 500,
            isError: false
        )

        let result = try await mockService.execute(
            prompt: "Test prompt",
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: "test-session",
            onMessage: { _ in }
        )

        XCTAssertTrue(mockService.executeCalled)
        XCTAssertEqual(mockService.lastPrompt, "Test prompt")
        XCTAssertEqual(mockService.lastPermissionMode, .plan)
        XCTAssertEqual(mockService.lastSessionId, "test-session")
        XCTAssertNil(mockService.lastTimeout)
        XCTAssertEqual(result.result, "Success")
    }

    func testExecutePromptWithoutTimeoutPassesNilTimeout() async throws {
        _ = try await mockService.execute(
            prompt: "Prompt",
            workingDirectory: tempDirectory,
            permissionMode: .acceptEdits,
            sessionId: nil,
            onMessage: { _ in }
        )

        XCTAssertNil(mockService.lastTimeout)
    }

    // MARK: - Content-Based Execution Tests

    func testExecuteContentWithTextOnlyDelegatesToPromptMethod() async throws {
        let content = PromptContent(text: "Text only prompt")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: "content-session",
            timeout: 60.0,
            onMessage: { _ in }
        )

        XCTAssertTrue(mockService.executeCalled)
        XCTAssertEqual(mockService.lastPrompt, "Text only prompt")
        XCTAssertEqual(mockService.lastSessionId, "content-session")
        XCTAssertEqual(mockService.lastTimeout, 60.0)
    }

    func testExecuteContentPreservesPermissionMode() async throws {
        let content = PromptContent(text: "Test")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .acceptEdits,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastPermissionMode, .acceptEdits)
    }

    func testExecuteContentWithEmptyText() async throws {
        let content = PromptContent(text: "")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastPrompt, "")
    }

    // MARK: - Convenience Method Tests (content without timeout)

    func testExecuteContentWithoutTimeoutDelegatesToFullMethod() async throws {
        let content = PromptContent(text: "No timeout content")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: "session",
            onMessage: { _ in }
        )

        XCTAssertTrue(mockService.executeCalled)
        XCTAssertEqual(mockService.lastPrompt, "No timeout content")
        XCTAssertNil(mockService.lastTimeout)
    }

    // MARK: - Message Callback Tests

    func testExecuteContentForwardsMessagesToCallback() async throws {
        let content = PromptContent(text: "Test")
        let expectedMessage = ClaudeStreamMessage.system(SystemMessage(
            subtype: "init",
            sessionId: "test-session",
            cwd: "/tmp",
            tools: [],
            model: "claude-3",
            permissionMode: "plan",
            mcpServers: [],
            slashCommands: [],
            claudeCodeVersion: "1.0.0",
            agents: []
        ))
        mockService.messagesToSend = [expectedMessage]

        let messageCounter = MessageCounter()

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in
                await messageCounter.increment()
            }
        )

        let count = await messageCounter.count
        XCTAssertEqual(count, 1)
    }

    // MARK: - Error Propagation Tests

    func testExecuteContentPropagatesErrors() async {
        let content = PromptContent(text: "Will fail")
        mockService.executeError = ClaudeCLIServiceError.noResultMessage

        do {
            _ = try await mockService.execute(
                content: content,
                workingDirectory: tempDirectory,
                permissionMode: .plan,
                sessionId: nil,
                timeout: nil,
                onMessage: { _ in }
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ClaudeCLIServiceError)
        }
    }

    // MARK: - Result Tests

    func testExecuteContentReturnsResult() async throws {
        let content = PromptContent(text: "Get result")
        mockService.executeResult = ClaudeExecutionResult(
            result: "Task completed",
            sessionId: "result-session",
            totalCostUsd: 0.05,
            durationMs: 1000,
            isError: false
        )

        let result = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(result.result, "Task completed")
        XCTAssertEqual(result.sessionId, "result-session")
        XCTAssertEqual(result.totalCostUsd, 0.05)
        XCTAssertEqual(result.durationMs, 1000)
        XCTAssertFalse(result.isError)
    }

    // MARK: - Default Implementation Behavior Tests

    func testDefaultImplementationExtractsTextFromContent() async throws {
        let image = makeTestImage()
        let content = PromptContent(text: "Text with image", images: [image])

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        // The default implementation only passes text, images are handled by
        // the concrete implementation in ClaudeCLIService (Task 4.3)
        XCTAssertEqual(mockService.lastPrompt, "Text with image")
    }

    func testDefaultImplementationIgnoresImagesInFallback() async throws {
        let images = [makeTestImage(), makeTestImage()]
        let content = PromptContent(text: "Multiple images", images: images)

        XCTAssertTrue(content.hasImages)
        XCTAssertEqual(content.images.count, 2)

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        // Default implementation passes only text
        XCTAssertEqual(mockService.lastPrompt, "Multiple images")
    }

    // MARK: - Mock Tracking Tests

    func testMockTracksLastContent() async throws {
        let image = makeTestImage()
        let content = PromptContent(text: "Track content", images: [image])

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastContent?.text, "Track content")
        XCTAssertEqual(mockService.lastContent?.images.count, 1)
    }

    func testMockTracksAllContents() async throws {
        let content1 = PromptContent(text: "First")
        let content2 = PromptContent(text: "Second", images: [makeTestImage()])

        _ = try await mockService.execute(
            content: content1,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        _ = try await mockService.execute(
            content: content2,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.allContents.count, 2)
        XCTAssertEqual(mockService.allContents[0].text, "First")
        XCTAssertEqual(mockService.allContents[1].text, "Second")
        XCTAssertTrue(mockService.allContents[1].hasImages)
    }

    func testMockContentTrackingIndependentOfPromptTracking() async throws {
        let content = PromptContent(text: "Content call")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        _ = try await mockService.execute(
            prompt: "Prompt call",
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.allContents.count, 1)
        XCTAssertEqual(mockService.allPrompts.count, 2)
        XCTAssertEqual(mockService.lastPrompt, "Prompt call")
        XCTAssertEqual(mockService.lastContent?.text, "Content call")
    }
}
