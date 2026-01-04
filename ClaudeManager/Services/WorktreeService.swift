import Foundation

// MARK: - Error Types

enum WorktreeServiceError: Error, LocalizedError {
    case commandFailed(Int32, stderr: String?)
    case directoryCreationFailed(path: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let code, let stderr):
            let stderrInfo = stderr.map { ": \($0)" } ?? ""
            return "Git worktree command failed with exit code \(code)\(stderrInfo)"
        case .directoryCreationFailed(let path):
            return "Failed to create directory: \(path)"
        }
    }
}

// MARK: - WorktreeService

final class WorktreeService: WorktreeServiceProtocol, @unchecked Sendable {
    private let gitPath: String

    init(gitPath: String = "/usr/bin/git") {
        self.gitPath = gitPath
    }

    // MARK: - WorktreeServiceProtocol

    func createWorktree(from repoPath: URL) async throws -> WorktreeInfo {
        let id = UUID()
        let worktreesDirPath = repoPath.appendingPathComponent(".worktrees")
        let worktreePath = worktreesDirPath.appendingPathComponent(id.uuidString)
        let branchName = "claude-worktree-\(id.uuidString)"

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: worktreesDirPath.path) {
            do {
                try fileManager.createDirectory(at: worktreesDirPath, withIntermediateDirectories: true)
            } catch {
                throw WorktreeServiceError.directoryCreationFailed(path: worktreesDirPath.path)
            }
        }

        try await runGit(
            arguments: ["worktree", "add", worktreePath.path, "-b", branchName],
            in: repoPath
        )

        return WorktreeInfo(
            id: id,
            originalRepoPath: repoPath,
            worktreePath: worktreePath,
            branchName: branchName,
            createdAt: Date()
        )
    }

    func removeWorktree(_ worktreeInfo: WorktreeInfo) async throws {
        try await runGit(
            arguments: ["worktree", "remove", worktreeInfo.worktreePath.path],
            in: worktreeInfo.originalRepoPath
        )
    }

    func listWorktrees(in repoPath: URL) async throws -> [WorktreeInfo] {
        let output = try await runGit(
            arguments: ["worktree", "list", "--porcelain"],
            in: repoPath
        )

        guard let output = output else {
            return []
        }

        return parseWorktreeList(output, originalRepoPath: repoPath)
    }

    // MARK: - Private Helpers

    private func parseWorktreeList(_ output: String, originalRepoPath: URL) -> [WorktreeInfo] {
        var worktrees: [WorktreeInfo] = []
        let worktreesDirPath = originalRepoPath.appendingPathComponent(".worktrees").path

        let entries = output.components(separatedBy: "\n\n")

        for entry in entries {
            guard !entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let lines = entry.components(separatedBy: "\n")
            var worktreePath: String?
            var branchName: String?

            for line in lines {
                if line.hasPrefix("worktree ") {
                    worktreePath = String(line.dropFirst("worktree ".count))
                } else if line.hasPrefix("branch ") {
                    let fullRef = String(line.dropFirst("branch ".count))
                    if fullRef.hasPrefix("refs/heads/") {
                        branchName = String(fullRef.dropFirst("refs/heads/".count))
                    } else {
                        branchName = fullRef
                    }
                }
            }

            guard let path = worktreePath,
                  path.hasPrefix(worktreesDirPath),
                  let branch = branchName else {
                continue
            }

            let pathURL = URL(fileURLWithPath: path)
            let uuidString = pathURL.lastPathComponent

            guard let id = UUID(uuidString: uuidString) else {
                continue
            }

            let worktreeInfo = WorktreeInfo(
                id: id,
                originalRepoPath: originalRepoPath,
                worktreePath: pathURL,
                branchName: branch,
                createdAt: Date()
            )

            worktrees.append(worktreeInfo)
        }

        return worktrees
    }

    @discardableResult
    private func runGit(arguments: [String], in directory: URL) async throws -> String? {
        let gitPath = self.gitPath

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: gitPath)
                process.arguments = arguments
                process.currentDirectoryURL = directory
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: WorktreeServiceError.commandFailed(-1, stderr: error.localizedDescription))
                    return
                }

                process.waitUntilExit()

                let exitCode = process.terminationStatus

                if exitCode != 0 {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrString = String(data: stderrData, encoding: .utf8)
                    continuation.resume(throwing: WorktreeServiceError.commandFailed(exitCode, stderr: stderrString))
                    return
                }

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: stdoutData, encoding: .utf8))
            }
        }
    }
}
