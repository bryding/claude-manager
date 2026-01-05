import Foundation

protocol WorktreeServiceProtocol: Sendable {
    func createWorktree(from repoPath: URL) async throws -> WorktreeInfo
    func removeWorktree(_ worktreeInfo: WorktreeInfo) async throws
    func listWorktrees(in repoPath: URL) async throws -> [WorktreeInfo]
}
