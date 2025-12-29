import Foundation
@testable import ClaudeManager

final class MockGitService: GitServiceProtocol, @unchecked Sendable {
    var commitResult: GitServiceResult = .noChanges
    var commitError: Error?
    var commitCalled = false
    var lastCommitMessage: String?

    func commitAll(message: String, in directory: URL) async throws -> GitServiceResult {
        commitCalled = true
        lastCommitMessage = message

        if let error = commitError {
            throw error
        }

        return commitResult
    }
}
