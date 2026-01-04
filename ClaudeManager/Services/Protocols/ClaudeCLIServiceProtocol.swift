import Foundation

protocol ClaudeCLIServiceProtocol: Sendable {
    func execute(
        prompt: String,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        timeout: TimeInterval?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult

    func execute(
        content: PromptContent,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        timeout: TimeInterval?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult

    func terminate()
    func interrupt()
    var isRunning: Bool { get }
}

extension ClaudeCLIServiceProtocol {
    func execute(
        prompt: String,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        try await execute(
            prompt: prompt,
            workingDirectory: workingDirectory,
            permissionMode: permissionMode,
            sessionId: sessionId,
            timeout: nil,
            onMessage: onMessage
        )
    }

    func execute(
        content: PromptContent,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        try await execute(
            content: content,
            workingDirectory: workingDirectory,
            permissionMode: permissionMode,
            sessionId: sessionId,
            timeout: nil,
            onMessage: onMessage
        )
    }

    func execute(
        content: PromptContent,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        timeout: TimeInterval?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        try await execute(
            prompt: content.text,
            workingDirectory: workingDirectory,
            permissionMode: permissionMode,
            sessionId: sessionId,
            timeout: timeout,
            onMessage: onMessage
        )
    }
}
