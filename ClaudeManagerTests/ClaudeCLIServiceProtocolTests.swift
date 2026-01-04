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

    // MARK: - Edge Case Tests

    func testMockTracksContentWithEmptyImagesArray() async throws {
        let content = PromptContent(text: "No images", images: [])

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastContent?.text, "No images")
        XCTAssertEqual(mockService.lastContent?.images.count, 0)
        XCTAssertFalse(mockService.lastContent?.hasImages ?? true)
    }

    func testMockLastContentIsNilBeforeFirstCall() {
        XCTAssertNil(mockService.lastContent)
        XCTAssertTrue(mockService.allContents.isEmpty)
    }

    func testMockContentOverwritesLastContent() async throws {
        let content1 = PromptContent(text: "First content", images: [makeTestImage()])
        let content2 = PromptContent(text: "Second content")

        _ = try await mockService.execute(
            content: content1,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastContent?.text, "First content")
        XCTAssertEqual(mockService.lastContent?.images.count, 1)

        _ = try await mockService.execute(
            content: content2,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastContent?.text, "Second content")
        XCTAssertEqual(mockService.lastContent?.images.count, 0)
    }

    func testMockContentWithMultipleImages() async throws {
        let images = [makeTestImage(), makeTestImage(), makeTestImage()]
        let content = PromptContent(text: "Multiple images", images: images)

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastContent?.images.count, 3)
        XCTAssertTrue(mockService.lastContent?.hasImages ?? false)
    }

    // MARK: - Error Handling Tests for Content Execution

    func testMockContentExecutionPropagatesTimeoutError() async {
        let content = PromptContent(text: "Will timeout")
        mockService.failuresBeforeSuccess = 1

        do {
            _ = try await mockService.execute(
                content: content,
                workingDirectory: tempDirectory,
                permissionMode: .plan,
                sessionId: nil,
                timeout: nil,
                onMessage: { _ in }
            )
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertTrue(error is ClaudeProcessError)
        }

        XCTAssertEqual(mockService.lastContent?.text, "Will timeout")
        XCTAssertEqual(mockService.allContents.count, 1)
    }

    func testMockContentStillTrackedOnError() async {
        let content = PromptContent(text: "Track despite error", images: [makeTestImage()])
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
            XCTFail("Expected error")
        } catch {
            // Expected
        }

        XCTAssertEqual(mockService.lastContent?.text, "Track despite error")
        XCTAssertEqual(mockService.lastContent?.images.count, 1)
        XCTAssertEqual(mockService.allContents.count, 1)
    }

    // MARK: - State Transition Tests

    func testMockContentExecutionIncrementsCallCount() async throws {
        let content = PromptContent(text: "Count me")

        XCTAssertEqual(mockService.executeCallCount, 0)

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.executeCallCount, 1)

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.executeCallCount, 2)
    }

    func testMockContentExecutionSetsExecuteCalled() async throws {
        let content = PromptContent(text: "Set flag")

        XCTAssertFalse(mockService.executeCalled)

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertTrue(mockService.executeCalled)
    }

    func testMockContentExecutionAlsoTracksPrompt() async throws {
        let content = PromptContent(text: "Text goes to prompt too")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastPrompt, "Text goes to prompt too")
        XCTAssertEqual(mockService.allPrompts.count, 1)
        XCTAssertEqual(mockService.allPrompts.first, "Text goes to prompt too")
    }

    // MARK: - Access Images via lastContent Tests

    func testAccessImagesViaLastContent() async throws {
        let image = makeTestImage()
        let content = PromptContent(text: "Image access", images: [image])

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        let images = mockService.lastContent?.images
        XCTAssertNotNil(images)
        XCTAssertEqual(images?.count, 1)
        XCTAssertEqual(images?.first?.mediaType, .png)
    }

    // MARK: - All Permission Modes Tests

    func testExecuteContentWithDefaultPermissionMode() async throws {
        let content = PromptContent(text: "Default mode")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .default,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastPermissionMode, .default)
    }

    func testExecuteContentWithAllPermissionModes() async throws {
        let modes: [PermissionMode] = [.plan, .acceptEdits, .default]

        for mode in modes {
            mockService = MockClaudeCLIService()
            let content = PromptContent(text: "Test \(mode)")

            _ = try await mockService.execute(
                content: content,
                workingDirectory: tempDirectory,
                permissionMode: mode,
                sessionId: nil,
                timeout: nil,
                onMessage: { _ in }
            )

            XCTAssertEqual(mockService.lastPermissionMode, mode)
        }
    }

    // MARK: - Timeout Boundary Tests

    func testExecuteContentWithZeroTimeout() async throws {
        let content = PromptContent(text: "Zero timeout")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: 0,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastTimeout, 0)
    }

    func testExecuteContentWithLargeTimeout() async throws {
        let content = PromptContent(text: "Large timeout")
        let largeTimeout: TimeInterval = 3600.0  // 1 hour

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: largeTimeout,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastTimeout, largeTimeout)
    }

    // MARK: - Session ID Tests

    func testExecuteContentWithEmptySessionId() async throws {
        let content = PromptContent(text: "Empty session")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: "",
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastSessionId, "")
    }

    func testExecuteContentWithLongSessionId() async throws {
        let content = PromptContent(text: "Long session")
        let longSessionId = String(repeating: "a", count: 1000)

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: longSessionId,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastSessionId, longSessionId)
    }

    // MARK: - Content with Special Characters Tests

    func testExecuteContentWithSpecialCharacters() async throws {
        let content = PromptContent(text: "Test with émojis 🎉 and unicode: 日本語")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastPrompt, "Test with émojis 🎉 and unicode: 日本語")
    }

    func testExecuteContentWithNewlines() async throws {
        let content = PromptContent(text: "Line 1\nLine 2\nLine 3")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastPrompt, "Line 1\nLine 2\nLine 3")
    }

    // MARK: - Result isError Flag Tests

    func testExecuteContentReturnsErrorResult() async throws {
        let content = PromptContent(text: "Will have error result")
        mockService.executeResult = ClaudeExecutionResult(
            result: "Error occurred",
            sessionId: "error-session",
            totalCostUsd: 0.0,
            durationMs: 50,
            isError: true
        )

        let result = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.result, "Error occurred")
    }

    // MARK: - Multiple Messages Callback Tests

    func testExecuteContentForwardsMultipleMessages() async throws {
        let content = PromptContent(text: "Multiple messages")
        let messages = [
            ClaudeStreamMessage.system(SystemMessage(
                subtype: "init",
                sessionId: "multi-session",
                cwd: "/tmp",
                tools: [],
                model: "claude-3",
                permissionMode: "plan",
                mcpServers: [],
                slashCommands: [],
                claudeCodeVersion: "1.0.0",
                agents: []
            )),
            ClaudeStreamMessage.result(ResultMessage(
                subtype: "success",
                isError: false,
                durationMs: 100,
                durationApiMs: 80,
                numTurns: 1,
                result: "Done",
                sessionId: "multi-session",
                totalCostUsd: 0.01,
                usage: UsageInfo(
                    inputTokens: 100,
                    outputTokens: 50,
                    cacheCreationInputTokens: nil,
                    cacheReadInputTokens: nil
                )
            ))
        ]
        mockService.messagesToSend = messages

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
        XCTAssertEqual(count, 2)
    }
}
