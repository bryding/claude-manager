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
}
