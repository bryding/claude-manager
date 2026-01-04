import Foundation
@testable import ClaudeManager

final class MockWorktreeService: WorktreeServiceProtocol, @unchecked Sendable {
    // Configurable results
    var createWorktreeResult: WorktreeInfo?
    var createWorktreeError: Error?
    var removeWorktreeError: Error?
    var listWorktreesResult: [WorktreeInfo] = []
    var listWorktreesError: Error?

    // Call tracking
    var createWorktreeCalled = false
    var removeWorktreeCalled = false
    var listWorktreesCalled = false

    // Parameter capture
    var lastCreateRepoPath: URL?
    var lastRemovedWorktree: WorktreeInfo?
    var lastListRepoPath: URL?

    func createWorktree(from repoPath: URL) async throws -> WorktreeInfo {
        createWorktreeCalled = true
        lastCreateRepoPath = repoPath

        if let error = createWorktreeError {
            throw error
        }

        return createWorktreeResult ?? WorktreeInfo(
            originalRepoPath: repoPath,
            worktreePath: repoPath.appendingPathComponent(".worktrees/\(UUID().uuidString)"),
            branchName: "claude-worktree-\(UUID().uuidString)"
        )
    }

    func removeWorktree(_ worktreeInfo: WorktreeInfo) async throws {
        removeWorktreeCalled = true
        lastRemovedWorktree = worktreeInfo

        if let error = removeWorktreeError {
            throw error
        }
    }

    func listWorktrees(in repoPath: URL) async throws -> [WorktreeInfo] {
        listWorktreesCalled = true
        lastListRepoPath = repoPath

        if let error = listWorktreesError {
            throw error
        }

        return listWorktreesResult
    }
}
