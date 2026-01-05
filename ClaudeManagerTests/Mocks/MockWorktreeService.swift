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
    private(set) var createWorktreeCalls: [URL] = []
    private(set) var removeWorktreeCalls: [WorktreeInfo] = []
    private(set) var listWorktreesCalls: [URL] = []

    var createWorktreeCalled: Bool { !createWorktreeCalls.isEmpty }
    var removeWorktreeCalled: Bool { !removeWorktreeCalls.isEmpty }
    var listWorktreesCalled: Bool { !listWorktreesCalls.isEmpty }

    var lastCreateRepoPath: URL? { createWorktreeCalls.last }
    var lastRemovedWorktree: WorktreeInfo? { removeWorktreeCalls.last }
    var lastListRepoPath: URL? { listWorktreesCalls.last }

    func createWorktree(from repoPath: URL) async throws -> WorktreeInfo {
        createWorktreeCalls.append(repoPath)

        if let error = createWorktreeError {
            throw error
        }

        if let result = createWorktreeResult {
            return result
        }

        let id = UUID()
        return WorktreeInfo(
            id: id,
            originalRepoPath: repoPath,
            worktreePath: repoPath.appendingPathComponent(".worktrees/\(id.uuidString)"),
            branchName: "claude-worktree-\(id.uuidString)"
        )
    }

    func removeWorktree(_ worktreeInfo: WorktreeInfo) async throws {
        removeWorktreeCalls.append(worktreeInfo)

        if let error = removeWorktreeError {
            throw error
        }
    }

    func listWorktrees(in repoPath: URL) async throws -> [WorktreeInfo] {
        listWorktreesCalls.append(repoPath)

        if let error = listWorktreesError {
            throw error
        }

        return listWorktreesResult
    }
}
