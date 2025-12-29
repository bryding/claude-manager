import Foundation

// MARK: - Error Types

enum GitServiceError: Error {
    case commandFailed(Int32, stderr: String?)
}

// MARK: - Result Types

struct GitServiceResult: Sendable {
    let success: Bool
    let message: String?

    static func committed(output: String?) -> GitServiceResult {
        GitServiceResult(success: true, message: output)
    }

    static func noChanges() -> GitServiceResult {
        GitServiceResult(success: true, message: "nothing to commit, working tree clean")
    }
}

// MARK: - Git Service

final class GitService: @unchecked Sendable {
    private let gitPath: String

    init(gitPath: String = "/usr/bin/git") {
        self.gitPath = gitPath
    }

    func commitAll(message: String, in directory: URL) async throws -> GitServiceResult {
        try await runGit(arguments: ["add", "-A"], in: directory)

        do {
            let output = try await runGit(arguments: ["commit", "-m", message], in: directory)
            return .committed(output: output)
        } catch GitServiceError.commandFailed(let code, let stderr) {
            if code == 1, let stderr = stderr, stderr.contains("nothing to commit") {
                return .noChanges()
            }
            throw GitServiceError.commandFailed(code, stderr: stderr)
        }
    }

    @discardableResult
    private func runGit(arguments: [String], in directory: URL) async throws -> String? {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let exitCode = process.terminationStatus

        if exitCode != 0 {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrString = String(data: stderrData, encoding: .utf8)
            throw GitServiceError.commandFailed(exitCode, stderr: stderrString)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: stdoutData, encoding: .utf8)
    }
}
