import XCTest
@testable import ClaudeManager

final class ClaudeCLIServiceTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
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

    // MARK: - Initialization Tests

    func testInitWithExplicitPath() {
        let service = ClaudeCLIService(executablePath: "/custom/path/claude")

        XCTAssertEqual(service.executablePath, "/custom/path/claude")
    }

    func testInitWithNilPathUsesDefault() {
        let service = ClaudeCLIService(executablePath: nil)

        XCTAssertFalse(service.executablePath.isEmpty)
    }

    func testInitWithoutArgumentsUsesDefault() {
        let service = ClaudeCLIService()

        XCTAssertFalse(service.executablePath.isEmpty)
    }

    // MARK: - isRunning Tests

    func testIsRunningReturnsFalseInitially() {
        let service = ClaudeCLIService(executablePath: "/bin/echo")

        XCTAssertFalse(service.isRunning)
    }

    // MARK: - Executable Not Found Tests

    func testExecutePromptThrowsWhenExecutableNotFound() async {
        let service = ClaudeCLIService(executablePath: "/nonexistent/path/claude")

        do {
            _ = try await service.execute(
                prompt: "Test",
                workingDirectory: tempDirectory,
                permissionMode: .plan,
                sessionId: nil,
                timeout: nil,
                onMessage: { _ in }
            )
            XCTFail("Expected executableNotFound error")
        } catch let error as ClaudeCLIServiceError {
            if case .executableNotFound(let path) = error {
                XCTAssertEqual(path, "/nonexistent/path/claude")
            } else {
                XCTFail("Expected executableNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testExecuteContentThrowsWhenExecutableNotFound() async {
        let service = ClaudeCLIService(executablePath: "/nonexistent/path/claude")
        let content = PromptContent(text: "Test")

        do {
            _ = try await service.execute(
                content: content,
                workingDirectory: tempDirectory,
                permissionMode: .plan,
                sessionId: nil,
                timeout: nil,
                onMessage: { _ in }
            )
            XCTFail("Expected executableNotFound error")
        } catch let error as ClaudeCLIServiceError {
            if case .executableNotFound(let path) = error {
                XCTAssertEqual(path, "/nonexistent/path/claude")
            } else {
                XCTFail("Expected executableNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testExecuteContentWithImagesThrowsWhenExecutableNotFound() async {
        let service = ClaudeCLIService(executablePath: "/nonexistent/path/claude")
        let image = makeTestImage()
        let content = PromptContent(text: "Test with image", images: [image])

        do {
            _ = try await service.execute(
                content: content,
                workingDirectory: tempDirectory,
                permissionMode: .plan,
                sessionId: nil,
                timeout: nil,
                onMessage: { _ in }
            )
            XCTFail("Expected executableNotFound error")
        } catch let error as ClaudeCLIServiceError {
            if case .executableNotFound = error {
                // Expected
            } else {
                XCTFail("Expected executableNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - ClaudeCLIServiceError Tests

    func testNoResultMessageErrorDescription() {
        let error = ClaudeCLIServiceError.noResultMessage

        XCTAssertEqual(error.errorDescription, "No result message received from Claude CLI")
    }

    func testExecutableNotFoundErrorDescription() {
        let error = ClaudeCLIServiceError.executableNotFound("/path/to/claude")

        XCTAssertEqual(error.errorDescription, "Claude CLI not found at: /path/to/claude")
    }

    func testProcessErrorDescription() {
        let processError = ClaudeProcessError.timedOut
        let error = ClaudeCLIServiceError.processError(processError)

        XCTAssertEqual(error.errorDescription, "Process error: Process timed out")
    }

    // MARK: - isRetryable Tests

    func testNoResultMessageIsNotRetryable() {
        XCTAssertFalse(ClaudeCLIServiceError.noResultMessage.isRetryable)
    }

    func testExecutableNotFoundIsNotRetryable() {
        XCTAssertFalse(ClaudeCLIServiceError.executableNotFound("/path").isRetryable)
    }

    func testProcessErrorTimedOutIsRetryable() {
        let error = ClaudeCLIServiceError.processError(.timedOut)
        XCTAssertTrue(error.isRetryable)
    }

    func testProcessErrorInterruptedIsRetryable() {
        let error = ClaudeCLIServiceError.processError(.interrupted)
        XCTAssertTrue(error.isRetryable)
    }

    func testProcessErrorExitCode1IsRetryable() {
        let error = ClaudeCLIServiceError.processError(.nonZeroExitCode(1, stderr: nil))
        XCTAssertTrue(error.isRetryable)
    }

    func testProcessErrorExitCode2IsNotRetryable() {
        let error = ClaudeCLIServiceError.processError(.nonZeroExitCode(2, stderr: nil))
        XCTAssertFalse(error.isRetryable)
    }

    // MARK: - PermissionMode Tests

    func testPermissionModePlanCliValue() {
        XCTAssertEqual(PermissionMode.plan.cliValue, "plan")
    }

    func testPermissionModeAcceptEditsCliValue() {
        XCTAssertEqual(PermissionMode.acceptEdits.cliValue, "acceptEdits")
    }

    func testPermissionModeDefaultCliValue() {
        XCTAssertEqual(PermissionMode.default.cliValue, "default")
    }

    // MARK: - ClaudeExecutionResult Tests

    func testExecutionResultProperties() {
        let result = ClaudeExecutionResult(
            result: "Test result",
            sessionId: "session-abc",
            totalCostUsd: 0.123,
            durationMs: 5000,
            isError: true
        )

        XCTAssertEqual(result.result, "Test result")
        XCTAssertEqual(result.sessionId, "session-abc")
        XCTAssertEqual(result.totalCostUsd, 0.123)
        XCTAssertEqual(result.durationMs, 5000)
        XCTAssertTrue(result.isError)
    }

    func testExecutionResultWithZeroCost() {
        let result = ClaudeExecutionResult(
            result: "",
            sessionId: "",
            totalCostUsd: 0.0,
            durationMs: 0,
            isError: false
        )

        XCTAssertEqual(result.totalCostUsd, 0.0)
        XCTAssertEqual(result.durationMs, 0)
    }

    // MARK: - Terminate/Interrupt Tests

    func testTerminateDoesNotCrashWhenNoProcess() {
        let service = ClaudeCLIService(executablePath: "/bin/echo")

        service.terminate()

        XCTAssertFalse(service.isRunning)
    }

    func testInterruptDoesNotCrashWhenNoProcess() {
        let service = ClaudeCLIService(executablePath: "/bin/echo")

        service.interrupt()

        XCTAssertFalse(service.isRunning)
    }

    // MARK: - PromptContent Tests

    func testPromptContentHasImagesReturnsFalseWhenEmpty() {
        let content = PromptContent(text: "Test prompt")

        XCTAssertFalse(content.hasImages)
    }

    func testPromptContentHasImagesReturnsTrueWhenImagesPresent() {
        let image = makeTestImage()
        let content = PromptContent(text: "Test prompt", images: [image])

        XCTAssertTrue(content.hasImages)
    }

    func testPromptContentTextOnlyGeneratesTextBlock() {
        let content = PromptContent(text: "Hello world")

        let blocks = content.contentBlocks
        XCTAssertEqual(blocks.count, 1)
        if case .text(let text) = blocks[0] {
            XCTAssertEqual(text, "Hello world")
        } else {
            XCTFail("Expected text block")
        }
    }

    func testPromptContentWithImageGeneratesImageAndTextBlocks() {
        let image = makeTestImage()
        let content = PromptContent(text: "Describe this", images: [image])

        let blocks = content.contentBlocks
        XCTAssertEqual(blocks.count, 2)

        if case .image(let mediaType, _) = blocks[0] {
            XCTAssertEqual(mediaType, "image/png")
        } else {
            XCTFail("Expected image block first")
        }

        if case .text(let text) = blocks[1] {
            XCTAssertEqual(text, "Describe this")
        } else {
            XCTFail("Expected text block second")
        }
    }

    func testPromptContentEmptyTextDoesNotGenerateTextBlock() {
        let image = makeTestImage()
        let content = PromptContent(text: "", images: [image])

        let blocks = content.contentBlocks
        XCTAssertEqual(blocks.count, 1)
        if case .image = blocks[0] {
            // Expected
        } else {
            XCTFail("Expected only image block")
        }
    }

    func testPromptContentToJSONDataEncodesSuccessfully() throws {
        let content = PromptContent(text: "Test")

        let data = try content.toJSONData()
        XCTAssertFalse(data.isEmpty)

        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?.count, 1)
        XCTAssertEqual(json?[0]["type"] as? String, "text")
        XCTAssertEqual(json?[0]["text"] as? String, "Test")
    }

    func testPromptContentWithImageToJSONDataEncodesCorrectly() throws {
        let image = makeTestImage()
        let content = PromptContent(text: "Analyze", images: [image])

        let data = try content.toJSONData()
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?.count, 2)

        let imageBlock = json?[0]
        XCTAssertEqual(imageBlock?["type"] as? String, "image")
        let source = imageBlock?["source"] as? [String: Any]
        XCTAssertEqual(source?["type"] as? String, "base64")
        XCTAssertEqual(source?["media_type"] as? String, "image/png")
        XCTAssertNotNil(source?["data"] as? String)

        let textBlock = json?[1]
        XCTAssertEqual(textBlock?["type"] as? String, "text")
        XCTAssertEqual(textBlock?["text"] as? String, "Analyze")
    }

    func testPromptContentMultipleImagesOrderedCorrectly() {
        let image1 = makeTestImage()
        let image2 = makeTestImage()
        let content = PromptContent(text: "Compare", images: [image1, image2])

        let blocks = content.contentBlocks
        XCTAssertEqual(blocks.count, 3)

        if case .image = blocks[0] {} else { XCTFail("First should be image") }
        if case .image = blocks[1] {} else { XCTFail("Second should be image") }
        if case .text = blocks[2] {} else { XCTFail("Third should be text") }
    }
}

// MARK: - MockClaudeCLIService Tests

final class MockClaudeCLIServiceTests: XCTestCase {

    private var mockService: MockClaudeCLIService!
    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        mockService = MockClaudeCLIService()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        mockService = nil
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

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

    // MARK: - Content Tracking Tests

    func testExecuteContentTracksLastContent() async throws {
        let content = PromptContent(text: "Test prompt")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastContent, content)
    }

    func testExecuteContentWithImagesTracksContent() async throws {
        let image = makeTestImage()
        let content = PromptContent(text: "Analyze image", images: [image])

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastContent?.text, "Analyze image")
        XCTAssertEqual(mockService.lastContent?.images.count, 1)
        XCTAssertTrue(mockService.lastContent?.hasImages ?? false)
    }

    func testExecuteContentAppendsToAllContents() async throws {
        let content1 = PromptContent(text: "First")
        let content2 = PromptContent(text: "Second")

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
    }

    func testExecuteContentAlsoSetsLastPrompt() async throws {
        let content = PromptContent(text: "Test prompt")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastPrompt, "Test prompt")
    }

    func testExecuteContentIncrementsCallCount() async throws {
        let content = PromptContent(text: "Test")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.executeCallCount, 1)
        XCTAssertTrue(mockService.executeCalled)
    }

    func testExecuteContentReturnsConfiguredResult() async throws {
        let expectedResult = ClaudeExecutionResult(
            result: "Custom result",
            sessionId: "custom-session",
            totalCostUsd: 0.5,
            durationMs: 2000,
            isError: false
        )
        mockService.executeResult = expectedResult
        let content = PromptContent(text: "Test")

        let result = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(result.result, "Custom result")
        XCTAssertEqual(result.sessionId, "custom-session")
        XCTAssertEqual(result.totalCostUsd, 0.5)
    }

    func testExecuteContentThrowsConfiguredError() async {
        mockService.executeError = ClaudeCLIServiceError.noResultMessage
        let content = PromptContent(text: "Test")

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
        } catch let error as ClaudeCLIServiceError {
            if case .noResultMessage = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testExecuteContentSendsConfiguredMessages() async throws {
        let systemMessage = ClaudeStreamMessage.system(SystemMessage(
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
        mockService.messagesToSend = [systemMessage]
        let content = PromptContent(text: "Test")
        var receivedMessages: [ClaudeStreamMessage] = []

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: nil,
            onMessage: { message in
                receivedMessages.append(message)
            }
        )

        XCTAssertEqual(receivedMessages.count, 1)
        if case .system(let msg) = receivedMessages[0] {
            XCTAssertEqual(msg.sessionId, "test-session")
        } else {
            XCTFail("Expected system message")
        }
    }

    func testExecuteContentPassesPermissionMode() async throws {
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

    func testExecuteContentPassesSessionId() async throws {
        let content = PromptContent(text: "Test")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: "resume-session-123",
            timeout: nil,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastSessionId, "resume-session-123")
    }

    func testExecuteContentPassesTimeout() async throws {
        let content = PromptContent(text: "Test")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            timeout: 30.0,
            onMessage: { _ in }
        )

        XCTAssertEqual(mockService.lastTimeout, 30.0)
    }

    // MARK: - Protocol Extension Default Tests

    func testProtocolExtensionWithoutTimeoutDelegatesToFullMethod() async throws {
        let content = PromptContent(text: "Test")

        _ = try await mockService.execute(
            content: content,
            workingDirectory: tempDirectory,
            permissionMode: .plan,
            sessionId: nil,
            onMessage: { _ in }
        )

        XCTAssertNil(mockService.lastTimeout)
        XCTAssertEqual(mockService.lastContent, content)
    }
}
