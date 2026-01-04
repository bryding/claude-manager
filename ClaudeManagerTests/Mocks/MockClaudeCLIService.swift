import Foundation
@testable import ClaudeManager

final class MockClaudeCLIService: ClaudeCLIServiceProtocol, @unchecked Sendable {
    var executeResult: ClaudeExecutionResult?
    var executeError: Error?
    var messagesToSend: [ClaudeStreamMessage] = []
    var executeCalled = false
    var lastPrompt: String?
    var lastContent: PromptContent?
    var lastImages: [AttachedImage]?
    var lastPermissionMode: PermissionMode?
    var lastSessionId: String?
    var lastTimeout: TimeInterval?
    var executeCallCount = 0
    var failuresBeforeSuccess = 0
    var allPrompts: [String] = []
    var allContents: [PromptContent] = []

    private var _isRunning = false
    var isRunning: Bool { _isRunning }

    func execute(
        prompt: String,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        timeout: TimeInterval?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        executeCalled = true
        executeCallCount += 1
        lastPrompt = prompt
        allPrompts.append(prompt)
        lastPermissionMode = permissionMode
        lastSessionId = sessionId
        lastTimeout = timeout
        _isRunning = true

        defer { _isRunning = false }

        for message in messagesToSend {
            await onMessage(message)
        }

        if failuresBeforeSuccess > 0 {
            failuresBeforeSuccess -= 1
            throw ClaudeProcessError.timedOut
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

    func execute(
        content: PromptContent,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        timeout: TimeInterval?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        lastContent = content
        lastImages = content.images
        allContents.append(content)

        return try await execute(
            prompt: content.text,
            workingDirectory: workingDirectory,
            permissionMode: permissionMode,
            sessionId: sessionId,
            timeout: timeout,
            onMessage: onMessage
        )
    }

    func terminate() {
        _isRunning = false
    }

    func interrupt() {
        _isRunning = false
    }
}
