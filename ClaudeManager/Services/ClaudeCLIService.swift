import Foundation

// MARK: - Permission Mode

enum PermissionMode: Sendable {
    case plan
    case acceptEdits
    case `default`

    var cliValue: String {
        switch self {
        case .plan: return "plan"
        case .acceptEdits: return "acceptEdits"
        case .default: return "default"
        }
    }
}

// MARK: - Execution Result

struct ClaudeExecutionResult: Sendable {
    let result: String
    let sessionId: String
    let totalCostUsd: Double
    let durationMs: Int
    let isError: Bool
}

// MARK: - Service Error

enum ClaudeCLIServiceError: Error, LocalizedError {
    case noResultMessage
    case processError(ClaudeProcessError)
    case executableNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noResultMessage:
            return "No result message received from Claude CLI"
        case .processError(let error):
            return "Process error: \(error.localizedDescription)"
        case .executableNotFound(let path):
            return "Claude CLI not found at: \(path)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .noResultMessage, .executableNotFound:
            return false
        case .processError(let error):
            return error.isRetryable
        }
    }
}

// MARK: - Claude CLI Service

final class ClaudeCLIService: ClaudeCLIServiceProtocol, @unchecked Sendable {
    let executablePath: String
    private var currentProcess: ClaudeProcess?

    init(executablePath: String? = nil) {
        self.executablePath = executablePath ?? Self.findClaudePath()
    }

    private static func findClaudePath() -> String {
        // Try common installation paths
        let commonPaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            NSHomeDirectory() + "/.nvm/versions/node/v22.15.0/bin/claude",
            NSHomeDirectory() + "/.npm-global/bin/claude"
        ]

        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: try to find using shell
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-l", "-c", "which claude"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            // Ignore errors, fall through to default
        }

        return "/usr/local/bin/claude"
    }

    func execute(
        prompt: String,
        workingDirectory: URL,
        permissionMode: PermissionMode,
        sessionId: String? = nil,
        timeout: TimeInterval? = nil,
        onMessage: @escaping @Sendable (ClaudeStreamMessage) async -> Void
    ) async throws -> ClaudeExecutionResult {
        // Verify executable exists
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            print("[ClaudeCLI] Executable not found at: \(executablePath)")
            throw ClaudeCLIServiceError.executableNotFound(executablePath)
        }

        print("[ClaudeCLI] Using executable: \(executablePath)")
        print("[ClaudeCLI] Working directory: \(workingDirectory.path)")

        let arguments = buildArguments(
            prompt: prompt,
            permissionMode: permissionMode,
            sessionId: sessionId
        )

        print("[ClaudeCLI] Arguments: \(arguments)")

        let process = ClaudeProcess(
            executablePath: executablePath,
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout
        )
        currentProcess = process

        var resultMessage: ResultMessage?

        do {
            for try await message in process.run() {
                await onMessage(message)

                if case .result(let result) = message {
                    resultMessage = result
                }
            }
        } catch let error as ClaudeProcessError {
            print("[ClaudeCLI] Process error: \(error)")
            currentProcess = nil
            throw ClaudeCLIServiceError.processError(error)
        }

        currentProcess = nil

        guard let result = resultMessage else {
            print("[ClaudeCLI] No result message received")
            throw ClaudeCLIServiceError.noResultMessage
        }

        return ClaudeExecutionResult(
            result: result.result,
            sessionId: result.sessionId,
            totalCostUsd: result.totalCostUsd,
            durationMs: result.durationMs,
            isError: result.isError
        )
    }

    func terminate() {
        currentProcess?.terminate()
    }

    func interrupt() {
        currentProcess?.interrupt()
    }

    var isRunning: Bool {
        currentProcess?.isRunning ?? false
    }

    private func buildArguments(
        prompt: String,
        permissionMode: PermissionMode,
        sessionId: String?
    ) -> [String] {
        var args: [String] = [
            "-p",
            "--output-format", "stream-json",
            "--verbose",
            "--permission-mode", permissionMode.cliValue
        ]

        if let sessionId = sessionId {
            args.append(contentsOf: ["--resume", sessionId])
        }

        args.append(prompt)

        return args
    }
}
