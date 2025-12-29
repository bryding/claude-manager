import Foundation
@testable import ClaudeManager

final class MockClaudeCLIService: ClaudeCLIServiceProtocol, @unchecked Sendable {
    var executeResult: ClaudeExecutionResult?
    var executeError: Error?
    var messagesToSend: [ClaudeStreamMessage] = []
    var executeCalled = false
    var lastPrompt: String?
    var lastPermissionMode: PermissionMode?

    private var _isRunning = false
    var isRunning: Bool { _isRunning }

    func execute(
        prompt: String,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        executeCalled = true
        lastPrompt = prompt
        lastPermissionMode = permissionMode
        _isRunning = true

        defer { _isRunning = false }

        for message in messagesToSend {
            await onMessage(message)
        }

        if let error = executeError {
            throw error
        }

        guard let result = executeResult else {
            let defaultPlanResult = """
            ## Task 1: Mock Task
            **Description:** This is a mock task for testing
            - [ ] Complete the implementation
            """
            return ClaudeExecutionResult(
                result: defaultPlanResult,
                sessionId: "mock-session-id",
                totalCostUsd: 0.0,
                durationMs: 100,
                isError: false
            )
        }

        return result
    }

    func terminate() {
        _isRunning = false
    }

    func interrupt() {
        _isRunning = false
    }
}
