import Foundation

// MARK: - Error Types

enum GitServiceError: Error, LocalizedError {
    case commandFailed(Int32, stderr: String?)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let code, let stderr):
            let stderrInfo = stderr.map { ": \($0)" } ?? ""
            return "Git command failed with exit code \(code)\(stderrInfo)"
        }
    }
}

// MARK: - Result Types

enum GitServiceResult: Sendable {
    case committed(output: String?)
    case noChanges
}

// MARK: - Git Service

final class GitService: GitServiceProtocol, @unchecked Sendable {
    private let gitPath: String

    init(gitPath: String = "/usr/bin/git") {
        self.gitPath = gitPath
    }

    func commitAll(message: String, in directory: URL) async throws -> GitServiceResult {
        print("[Git] Adding all changes in: \(directory.path)")
        try await runGit(arguments: ["add", "-A"], in: directory)

        do {
            print("[Git] Committing with message: \(message.prefix(50))...")
            let output = try await runGit(arguments: ["commit", "-m", message], in: directory)
            print("[Git] Commit successful")
            return .committed(output: output)
        } catch GitServiceError.commandFailed(let code, let stderr) {
            print("[Git] Commit failed with code \(code): \(stderr ?? "no stderr")")
            if code == 1, let stderr = stderr, stderr.contains("nothing to commit") {
                return .noChanges
            }
            throw GitServiceError.commandFailed(code, stderr: stderr)
        }
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
                    continuation.resume(throwing: GitServiceError.commandFailed(-1, stderr: error.localizedDescription))
                    return
                }

                process.waitUntilExit()

                let exitCode = process.terminationStatus

                if exitCode != 0 {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrString = String(data: stderrData, encoding: .utf8)
                    continuation.resume(throwing: GitServiceError.commandFailed(exitCode, stderr: stderrString))
                    return
                }

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: stdoutData, encoding: .utf8))
            }
        }
    }
}
