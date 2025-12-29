import Foundation

protocol ClaudeCLIServiceProtocol: Sendable {
    func execute(
        prompt: String,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String?,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult

    func terminate()
    func interrupt()
    var isRunning: Bool { get }
}
