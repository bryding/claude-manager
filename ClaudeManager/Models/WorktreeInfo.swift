import Foundation

// MARK: - WorktreeInfo

struct WorktreeInfo: Identifiable, Sendable, Equatable {
    let id: UUID
    let originalRepoPath: URL
    let worktreePath: URL
    let branchName: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        originalRepoPath: URL,
        worktreePath: URL,
        branchName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.originalRepoPath = originalRepoPath
        self.worktreePath = worktreePath
        self.branchName = branchName
        self.createdAt = createdAt
    }
}
